defmodule RabbitHole.Task.ProducerConsumerTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel}
  alias RabbitHole.Task.{Producer, Consumer}
  alias RabbitHole.Task.{Fun, MFA, Other}

  require Logger

  @task_exchange "task_exchange"
  @enqueue_message_delay 200
  @task_types [Fun, MFA, Other]

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
    test "other task", params do
      publish_task_test(other_task(), params.chan)
    end

    test "fun task", params do
      publish_task_test(fun_task(), params.chan)
    end

    test "MFA task", params do
      publish_task_test(mfa_task(), params.chan)
    end

    defp publish_task_test({task, _result}, _chan) do
      # GIVEN
      {:ok, ref} = Producer.start(@task_exchange)

      # WHEN
      Logger.debug("Publishing: #{inspect(task)}")
      :ok = Producer.publish(ref, task)

      # CLEANUP
      :ok = Producer.stop(ref)
    end
  end

  describe "publish and consume" do
    test "other task", params do
      publish_and_consume_task_test(other_task(), params.chan)
    end

    test "fun task", params do
      publish_and_consume_task_test(fun_task(), params.chan)
    end

    test "MFA task", params do
      publish_and_consume_task_test(mfa_task(), params.chan)
    end

    defp publish_and_consume_task_test({task, result}, _chan) do
      # GIVEN
      {:ok, ref} = Producer.start(@task_exchange)
      me = self()

      processor = fn task, consumer_ref ->
        send(me, {:processed, consumer_ref, task.__struct__, result})
      end

      task_type_to_consumer = start_consumers(@task_exchange, @task_types, processor)

      # WHEN
      Logger.debug("Publishing: #{inspect(task)}")
      :ok = Producer.publish(ref, task)
      %task_type{} = task
      consumer_ref = task_type_to_consumer[task_type]

      # THEN
      assert_receive t = {:processed, ^consumer_ref, ^task_type, ^result}, @enqueue_message_delay
      Logger.debug("Received: #{inspect(t)}")
      refute_received _

      # CLEANUP
      stop_consumers(Map.values(task_type_to_consumer))
      :ok = Producer.stop(ref)
    end

    defp start_consumers(task_exchange, task_types, processor) when is_function(processor, 2) do
      for t <- task_types do
        {:ok, ref} = Consumer.start(task_exchange, t, processor: processor)
        {t, ref}
      end
      |> Enum.into(%{})
    end

    defp stop_consumers(consumer_refs) do
      for c <- consumer_refs, do: Consumer.stop(c)
    end
  end

  defp fun_task(), do: {%Fun{fun: fn list -> Enum.sum(list) end, args: [1, 2, 3]}, 6}
  defp mfa_task(), do: {%MFA{mod: Enum, fun: :sum, args: [1, 2, 3]}, 6}
  defp other_task(), do: {%Other{val: 6}, 6}
end
