defmodule RabbitHole.Protocol.QueueDeclareTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel, Queue}

  @queue "my_queue"

  describe "channel and connection kept open" do
    setup do
      {:ok, conn} = Connection.open()
      {:ok, chan} = Channel.open(conn)
      {:ok, _} = Queue.delete(chan, @queue)

      on_exit(fn ->
        :ok = Channel.close(chan)
        :ok = Connection.close(conn)
      end)

      [conn: conn, chan: chan]
    end

    test "declares a queue with auto-generated name", params do
      assert {:ok, queue} = Queue.declare(params.chan)
      assert {:ok, another_queue} = Queue.declare(params.chan)
      refute queue == another_queue
      {:ok, %{message_count: 0}} = Queue.delete(params.chan, queue)
    end

    test "declares a queue with a specified name", params do
      assert {:ok, @queue} = Queue.declare(params.chan, @queue)
      # redeclaration of the same queue checks its name and all its params
      assert {:ok, @queue} = Queue.declare(params.chan, @queue)
      {:ok, %{message_count: 0}} = Queue.delete(params.chan, @queue)
    end

    test "succeds if a queue with a given name already exits", params do
      assert {:ok, @queue} = Queue.declare(params.chan, @queue)
      # redeclaration of a queue with :passive checks if a queue with the same name exits
      assert {:ok, @queue} = Queue.declare(params.chan, @queue, [:passive])
      {:ok, %{message_count: 0}} = Queue.delete(params.chan, @queue)
    end
  end

  describe "channel and connection closed as a result of an error" do
    setup do
      {:ok, conn} = Connection.open()
      {:ok, chan} = Channel.open(conn)
      {:ok, _} = Queue.delete(chan, @queue)
      [conn: conn, chan: chan]
    end

    test "fails if a queue with the given name doesn't exists", params do
      # NOT_FOUND error
      assert {{:shutdown, {:server_initiated_close, 404, _}}, _}
        = catch_exit(Queue.declare(params.chan, @queue, [:passive]))
    end

    test "fails if a queue with different params already exists", params do
      # by default the queue is not durable
      assert {:ok, @queue} = Queue.declare(params.chan, @queue)
      # PRECONDITION_FAILED error
      assert {{:shutdown, {:server_initiated_close, 406, _}}, _}
       = catch_exit(Queue.declare(params.chan, @queue, [:durable]))
    end
  end

end
