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
    assert true = Confirm.wait_for_confirms(params.chan)
    assert Basic.cancel(params.chan, tag)
  end

  test "waits for multiple confirms", params do
    # GIVEN
    {:ok, tag} = Basic.consume(params.chan, params.queue, no_ack: false)
    :ok = Confirm.select(params.chan)

    # WHEN
    for _ <- 1..10, do: :ok = Basic.publish(params.chan, "", params.queue, @my_message)

    # THEN
    assert true = Confirm.wait_for_confirms(params.chan)
    assert Basic.cancel(params.chan, tag)
  end

  test "waits for multiple confirms via callback", params do
    {:ok, tag} = Basic.consume(params.chan, params.queue, no_ack: false)
    :ok = Confirm.select(params.chan)
    :ok = Confirm.register_handler(params.chan, self())

    receive_confirms = fn last_seq_no, callback ->
      receive do
        {:basic_ack, ^last_seq_no, _} ->
          :ok

        {:basic_nack, _, _} ->
          flunk("Received negative confirm")

        {:basic_ack, seqno, multiple?} ->
          Logger.debug("Received confirmations (multiple=#{multiple?}) up to #{seqno}")
          callback.(last_seq_no, callback)
      end
    end

    # WHEN
    for _ <- 1..9, do: :ok = Basic.publish(params.chan, "", params.queue, @my_message)
    last_seq_no = Confirm.next_publish_seqno(params.chan)
    :ok = Basic.publish(params.chan, "", params.queue, @my_message)


    # THEN
    assert :ok = receive_confirms.(last_seq_no, receive_confirms)
    assert Basic.cancel(params.chan, tag)
  end
end
