defmodule RabbitHole.Protocol.PublishWithConfirmTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel, Queue, Basic, Confirm}

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

  test "puts a channel into confirm mode and waits for confirms", params do
    # GIVEN
    {:ok, tag} = Basic.consume(params.chan, params.queue, no_ack: false)
    :ok = Confirm.select(params.chan)

    # WHEN
    :ok = Basic.publish(params.chan, "", params.queue, @my_message)

    # THEN
    true = Confirm.wait_for_confirms(params.chan)
  end

  test "waits for multiple confirms", params do
    # GIVEN
    {:ok, tag} = Basic.consume(params.chan, params.queue, no_ack: false)
    :ok = Confirm.select(params.chan)

    # WHEN
    for _ <- 1..10, do: :ok = Basic.publish(params.chan, "", params.queue, @my_message)

    # THEN
    true = Confirm.wait_for_confirms(params.chan)
  end
end
