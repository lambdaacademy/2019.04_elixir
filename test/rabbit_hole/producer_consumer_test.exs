defmodule RabbitHole.ProducerConsumerTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel, Queue}
  alias RabbitHole.{Producer, Consumer}

  @task_queue "task_queue"
  @short_task "This is short task."
  @long_task "This is long task..."
  @task_delay_ms 1000

  # TESTS

  setup do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)

    on_exit(fn ->
      :ok = Channel.close(chan)
      :ok = Connection.close(conn)
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
      assert Queue.message_count(params.chan, @task_queue)

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
      wu = work_units(@short_task)

      {:ok, c_ref} =
        Consumer.start(@task_queue,
          processor: fn task -> send(me, {:processed, ref, process(task)}) end
        )

      {:ok, p_ref} = Producer.start(@task_queue)

      # WHEN
      :ok = Producer.publish(p_ref, @short_task)

      # THEN
      assert_receive {:processed, ^ref, ^wu}

      # CLEANUP
      Producer.stop(p_ref)
      Consumer.stop(c_ref)
    end

    test "publishes a task and competing consumers consume" do
      # GIVEN
      me = self()
      ref1 = make_ref()
      ref2 = make_ref()
      processor = fn task -> send(me, {:processed, ref1, process(task)}) end

      {:ok, c_ref1} = Consumer.start(@task_queue, processor: processor)
      {:ok, c_ref2} = Consumer.start(@task_queue, processor: processor)
      wu1 = work_units(@short_task)
      wu2 = work_units(@long_task)

      {:ok, p_ref} = Producer.start(@task_queue)

      # WHEN
      for t <- [@short_task, @long_task], do: :ok = Producer.publish(p_ref, t)

      # THEN
      # @short_task processed by the first consumer
      assert_receive {:processed, ^ref1, ^wu1}
      # @long_taks processed by the second consumer
      assert_receive {:processed, ^ref2, ^wu2}

      # CLEANUP
      Producer.stop(p_ref)
      for c <- [c_ref1, c_ref2], do: Consumer.stop(c)
    end
  end

  # HELPERS

  defp process(task) do
    Enum.reduce(
      fn _, acc ->
        IO.puts("Processing")
        Process.sleep(@task_delay_ms)
        acc + 1
      end,
      0,
      1..work_units(task)
    )
  end

  defp work_units(task) do
    String.length(task) - (String.trim_trailing(task, ".") |> String.length())
  end
end
