defmodule RabbitHole.Protocol.ExchangeDeclareTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel, Exchange}

  @exchange "my_exchange"

  describe "channel and connection kept open" do
    setup do
      {:ok, conn} = Connection.open()
      {:ok, chan} = Channel.open(conn)
      :ok = Exchange.delete(chan, @exchange)

      on_exit(fn ->
        :ok = Channel.close(chan)
        :ok = Connection.close(conn)
      end)

      [conn: conn, chan: chan]
    end

    test "declares an exchange", params do
      assert exchange = Exchange.declare(params.chan, @exchange)
      # redeclaration of the same exchange checks its name and all its params
      assert ^exchange = Exchange.declare(params.chan, @exchange)
    end

    test "checks existence of an exchange", params do
      assert exchange = Exchange.declare(params.chan, @exchange)
      # redeclaration of a exchange with :passive checks if a exchange with the same name exits
      assert ^exchange = Exchange.declare(params.chan, @exchange, :direct, [:passive])
    end
  end

  describe "channel and connection closed as a result of an error" do
    setup do
      {:ok, conn} = Connection.open()
      {:ok, chan} = Channel.open(conn)
      :ok = Exchange.delete(chan, @exchange)
      [conn: conn, chan: chan]
    end

    test "fails if a exchange with the given name doesn't exists", params do
      # NOT_FOUND error
      assert {{:shutdown, {:server_initiated_close, 404, _}}, _} =
               catch_exit(Exchange.declare(params.chan, @exchange, :direct, [:passive]))
    end

    test "fails if a exchange with different type already exists", params do
      # by default the exchange if of type :direct
      assert exchange = Exchange.declare(params.chan, @exchange)
      # PRECONDITION_FAILED error
      assert {{:shutdown, {:server_initiated_close, 406, _}}, _} =
               catch_exit(Exchange.declare(params.chan, @exchange, :fanout))
    end

    test "fails if a exchange with different params already exists", params do
      # by default the exchange is not durable
      assert exchange = Exchange.declare(params.chan, @exchange)
      # PRECONDITION_FAILED error
      assert {{:shutdown, {:server_initiated_close, 406, _}}, _} =
               catch_exit(Exchange.declare(params.chan, @exchange, :direct, [:durable]))
    end
  end
end
