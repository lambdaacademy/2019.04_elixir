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
    # WHEN
    :ok = Basic.publish(params.chan, "", params.queue, @my_message)

    # THEN
    assert {:ok, %{message_count: 1}} =
      Queue.delete(params.chan, params.queue)
  end

  test "publishes to and consumes from a queue", params do
    # GIVEN
    {:ok, tag} = Basic.consume(params.chan, params.queue, no_ack: true)

    # WHEN
    :ok = Basic.publish(params.chan, "", params.queue, @my_message)
    {:ok, ^tag} = Basic.cancel(params.chan, tag)

    # THEN
    assert_received {:basic_deliver, @my_message, _meta}
    assert {:ok, %{message_count: 0}} =
      Queue.delete(params.chan, params.queue)
  end

end
