defmodule RabbitHole.ProducerConsumerTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel, Queue}
  alias RabbitHole.{Producer, Consumer}

  require Logger

  @task_queue "task_queue"
  @short_task "This is short task."
  @long_task "This is long task..."
  @task_delay_ms 10
  @enqueue_message_delay 200

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
          :ok
          Logger.warn("The connection and channel has already been closed")
      end
    end)

    [conn: conn, chan: chan]
  end

  describe "publish" do
    test "publishes tasks to a queue", params do
      # GIVEN
      {:ok, ref} = Producer.start(@task_queue)

      # WHEN
      :ok = Producer.publish(ref, @short_task)
      :ok = Producer.publish(ref, @long_task)

      # THEN
      Process.sleep(@enqueue_message_delay)
      assert 2 = Queue.message_count(params.chan, @task_queue)

      # CLEANUP
      :ok = Producer.stop(ref)
    end

    test "publishes tasks and clean-ups the queue on stop", params do
      # GIVEN
      {:ok, ref} = Producer.start(@task_queue)

      # WHEN
      :ok = Producer.publish(ref, @short_task)
      :ok = Producer.publish(ref, @long_task)

      # THEN
      :ok = Producer.stop(ref)

      assert {{:shutdown, {:server_initiated_close, 404, _}}, _} =
               catch_exit(Queue.declare(params.chan, @task_queue, [:passive]))
    end
  end

  describe "publish and consume" do
    test "publishes a task and it can be consumed" do
      # GIVEN
      me = self()
      ref = make_ref()
      wu = work_units(@long_task)

      {:ok, c_ref} =
        Consumer.start(@task_queue,
          processor: fn task -> send(me, {:processed, ref, process(task)}) end
        )

      {:ok, p_ref} = Producer.start(@task_queue)

      # WHEN
      :ok = Producer.publish(p_ref, @long_task)

      # THEN
      assert_receive {:processed, ^ref, ^wu}, @enqueue_message_delay

      # CLEANUP
      Consumer.stop(c_ref)
      Producer.stop(p_ref)
    end

    test "publishes a task and competing consumers consume" do
      # GIVEN
      me = self()
      ref1 = make_ref()
      ref2 = make_ref()
      processor1 = fn task -> send(me, {:processed, ref1, process(task)}) end
      processor2 = fn task -> send(me, {:processed, ref2, process(task)}) end
      {:ok, p_ref} = Producer.start(@task_queue)

      {:ok, c_ref1} = Consumer.start(@task_queue, processor: processor1)
      {:ok, c_ref2} = Consumer.start(@task_queue, processor: processor2)
      wu1 = work_units(@short_task)
      wu2 = work_units(@long_task)

      # WHEN
      for t <- [@short_task, @long_task], do: :ok = Producer.publish(p_ref, t)

      # THEN
      # @short_task processed by the first consumer
      assert_receive {:processed, ^ref1, ^wu1}, @enqueue_message_delay
      # @long_taks processed by the second consumer
      assert_receive {:processed, ^ref2, ^wu2}, @enqueue_message_delay

      # CLEANUP
      for c <- [c_ref1, c_ref2], do: Consumer.stop(c)
      Producer.stop(p_ref)
    end
  end

  # HELPERS

  defp process(task) do
    Logger.info("Processing: #{inspect task}")
    Enum.reduce(
      1..work_units(task),
      0,
      fn _, acc ->
        Logger.info("[x]")
        Process.sleep(@task_delay_ms)
        acc + 1
      end
    )
  end

  defp work_units(task) do
    String.length(task) - (String.trim_trailing(task, ".") |> String.length())
  end
end
