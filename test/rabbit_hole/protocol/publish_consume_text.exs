defmodule RabbitHole.Protocol.PublishConsumeTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel, Queue, Basic}

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

  test "publishes to a queue", params do
    :ok = Basic.publish(params.chan, "", params.queue, @my_message)
    assert {:ok, %{message_count: 1}} =
      Queue.delete(params.chan, params.queue)
  end

  test "publishes to and consumes from a queue", params do
    :ok = Basic.publish(params.chan, "", params.queue, @my_message)
    {:ok, _} = Basic.consume(params.chan, params.queue)
    assert_receive {:basic_deliver, @my_message, _meta}
    assert {:ok, %{message_count: 0}} =
      Queue.delete(params.chan, params.queue)
  end

end
