defmodule RabbitHole.Protocol.ConsumeWithAckTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel, Queue, Basic}

  require Logger

  @my_queue "my_queue"
  @my_message "Hello Rabbit, this is Elixir! We have a lot in common..."

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {:ok, _} = Queue.delete(chan, @my_queue)
    {:ok, queue} = Queue.declare(chan, @my_queue)

    on_exit(fn ->
      :ok = Channel.close(chan)
      :ok = Connection.close(conn)
    end)

    [conn: conn, chan: chan, queue: queue]
  end

  describe "with auto acks" do
    test "message received by a consumer is already acked", params do
      # GIVEN
      :ok = Basic.publish(params.chan, "", params.queue, @my_message)

      # WHEN
      consume_once(params.queue, true)
      {:ok, _tag} = Basic.consume(params.chan, params.queue, no_ack: false)

      # THEN
      refute_received {:basic_deliver, @my_message, _meta}, 100
    end
  end

  describe "with manual acks" do
    test "message not acked by a consumer will be consumed by another one", params do
      # GIVEN
      :ok = Basic.publish(params.chan, "", params.queue, @my_message)

      # WHEN
      consume_once(params.queue, false)

      # THEN
      {:ok, _tag} = Basic.consume(params.chan, params.queue, no_ack: false)
      assert_receive {:basic_deliver, @my_message, meta}, 100
      assert meta.redelivered == true
      assert :ok = Basic.ack(params.chan, meta.delivery_tag)
    end

    test "prefetch will limit the number of messages until ack is send", params do
      # GIVEN
      # manual acks (i.e. no_ack: false) is set by default
      Basic.qos(params.chan, prefetch_count: 2)
      {:ok, _tag} = Basic.consume(params.chan, params.queue)

      # WHEN
      for _ <- 1..3 do
        :ok = Basic.publish(params.chan, "", params.queue, @my_message)
      end

      # THEN
      # get 2 message and receive
      assert_receive {:basic_deliver, @my_message, _meta}, 100
      assert_receive {:basic_deliver, @my_message, meta1}, 100
      refute_receive {:basic_deliver, @my_message, _meta}, 100
      # , [:multiple])
      Basic.ack(params.chan, meta1.delivery_tag)

      # get the last message and confirm
      assert_receive {:basic_deliver, @my_message, meta2}, 100
      Basic.ack(params.chan, meta2.delivery_tag)
    end

    test "messages over the prefetch limit are sent to another consumer", params do
      # GIVEN
      # manual acks (i.e. no_ack: false) is set by default
      Basic.qos(params.chan, prefetch_count: 2)
      {:ok, tag1} = Basic.consume(params.chan, params.queue)
      {:ok, tag2} = Basic.consume(params.chan, params.queue)

      # WHEN
      for _ <- 1..5 do
        :ok = Basic.publish(params.chan, "", params.queue, @my_message)
      end

      # THEN
      # get 4 message and ack
      metas =
        for _ <- 1..4 do
          assert_receive {:basic_deliver, @my_message, meta}, 100
          meta
        end

      refute_receive {:basic_deliver, @my_message, _meta}, 100
      assert 2 == Enum.count(metas, &(&1.consumer_tag == tag1))
      assert 2 == Enum.count(metas, &(&1.consumer_tag == tag2))
      Basic.ack(params.chan, List.last(metas).delivery_tag)

      # get the last message and confirm
      assert_receive {:basic_deliver, @my_message, meta}, 100
      Basic.ack(params.chan, meta.delivery_tag)
    end
  end

  defp consume_once(queue, no_ack) do
    Process.flag(:trap_exit, true)

    pid =
      spawn_link(fn ->
        {_, chan} = conn_chan = setup_conn_chan()
        {:ok, tag} = Basic.consume(chan, queue, no_ack: no_ack)

        receive do
          {:basic_deliver, @my_message, _meta} ->
            Logger.debug("Got message on #{tag}")
        end

        close_conn_chan(conn_chan)
      end)

    receive do
      {:EXIT, ^pid, :normal} -> :ok
      other -> Logger.debug("Instead of exit signal got #{inspect(other)}")
    end
  end

  defp setup_conn_chan() do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {conn, chan}
  end

  defp close_conn_chan({conn, chan}) do
    :ok = Channel.close(chan)
    :ok = Connection.close(conn)
  end
end
