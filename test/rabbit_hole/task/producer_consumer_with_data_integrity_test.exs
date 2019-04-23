defmodule RabbitHole.Task.ProducerConsumerWithDataIntegrityTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel}
  alias RabbitHole.Task.{Producer, Consumer}
  alias RabbitHole.Task.Other

  require Logger

  @task_exchange "task_exchange"

  # TESTS

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)

    on_exit(fn ->
      try do
        :ok = Channel.close(chan)
        :ok = Connection.close(conn)
      catch
        :exit, _ ->
          Logger.warn("The connection and channel has already been closed")
      end
    end)

    [conn: conn, chan: chan]
  end

  describe "publish" do
    test "notifies when all messages confirmed" do
      # GIVEN
      max_unconfirmed = 2
      me = self()
      confirm_timeout = 1000
      confirm_callback = fn pub_ref -> send(me, {:confirmed, pub_ref, self()}) end

      {:ok, ref} =
        Producer.start(@task_exchange, confirms: true, max_unconfirmed: max_unconfirmed)

      # WHEN
      msgs = Enum.reduce(1..max_unconfirmed, [], &[%Other{val: &1} | &2])
      {:ok, pub_ref} = Producer.publish(ref, msgs, confirm_callback: confirm_callback)

      # THEN
      assert_receive {:confirmed, ^pub_ref, ^ref}, confirm_timeout

      # CLEANUP
      :ok = Producer.stop(ref)
    end

    test "reject all if max uconfirmed reached" do
      # GIVEN
      max_unconfirmed = 2

      {:ok, ref} =
        Producer.start(@task_exchange, confirms: true, max_unconfirmed: max_unconfirmed)

      # WHEN
      msgs = Enum.reduce(1..(max_unconfirmed + 1), [], &[%Other{val: &1} | &2])
      {:ok, _pub_ref} = Producer.publish(ref, tl(msgs))

      # THEN
      assert {:rejected, :all} = Producer.publish(ref, hd(msgs))

      # CLEANUP
      :ok = Producer.stop(ref)
    end

    test "rejects over the confirm limit" do
      # GIVEN
      max_unconfirmed = 10

      {:ok, ref} =
        Producer.start(@task_exchange, confirms: true, max_unconfirmed: max_unconfirmed)

      # WHEN
      msgs = Enum.reduce(1..(max_unconfirmed + 1), [], &[%Other{val: &1} | &2])

      # THEN
      assert {:rejected, _pub_ref, {:over_limit, 1}} = Producer.publish(ref, msgs)

      # CLEANUP
      :ok = Producer.stop(ref)
    end

    test "notifies when all messages confirmed and then goes on" do
      # GIVEN
      max_unconfirmed = 10
      me = self()
      confirm_timeout = 1000
      confirm_callback = fn pub_ref -> send(me, {:confirmed, pub_ref, self()}) end

      {:ok, ref} =
        Producer.start(@task_exchange, confirms: true, max_unconfirmed: max_unconfirmed)

      # WHEN
      msgs = Enum.reduce(1..max_unconfirmed, [], &[%Other{val: &1} | &2])
      {:ok, pub_ref} = Producer.publish(ref, msgs, confirm_callback: confirm_callback)

      # THEN
      receive do
        {:confirmed, ^pub_ref, ^ref} -> :ok
      after
        confirm_timeout -> flunk("Confirms timeout ( #{confirm_timeout} ms)")
      end

      {:ok, _pub_ref} = Producer.publish(ref, %Other{val: "over limit"})

      # CLEANUP
      :ok = Producer.stop(ref)
    end

    ## TODO: multiple publishers sharing one limit
  end

  describe "publish and consume" do
    test "consumers get up to prefetch limit tasks" do
      # GIVEN
      prefetch = 1
      me = self()
      deliver_delay_ms = 100

      processor = fn task, consumer_ref ->
        send(me, {:processed, consumer_ref, task})

        receive do
          :continue -> :ok
        end
      end

      {:ok, p_ref} = Producer.start(@task_exchange)

      {:ok, c_ref} =
        Consumer.start(@task_exchange, Other,
          processor: processor,
          prefetch: prefetch
        )

      # WHEN
      :ok = Producer.publish(p_ref, [%Other{val: 1}, %Other{val: 2}])
      Process.sleep(deliver_delay_ms)

      # THEN
      assert_receive {:processed, ^c_ref, _task}
      assert {:message_queue_len, 0} = Process.info(c_ref, :message_queue_len)
      send(c_ref, :continue)
      assert_receive {:processed, ^c_ref, _task}
      send(c_ref, :continue)

      # CLEANUP
      Consumer.stop(c_ref)
      :ok = Producer.stop(p_ref)
    end
  end
end
