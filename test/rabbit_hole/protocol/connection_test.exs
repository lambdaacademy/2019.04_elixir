defmodule RabbitHole.Protocol.ConnectionTest do
  use ExUnit.Case

  require Logger
  alias RabbitHole.Protocol.{Connection, Channel}

  test "connects and creates a channel" do
    {:ok, conn} = Connection.open()
    {:ok, _chan} = Channel.open(conn)
  end

  describe "with connection" do
    setup do
      {:ok, conn} = Connection.open()

      on_exit(fn ->
        try do
          :ok = Connection.close(conn)
        catch
          :exit, _ ->
            :ok
            Logger.warn("The connection has already been closed")
        end
      end)

      %{conn: conn}
    end

    test "creates a channel", params do
      {:ok, chann} = Channel.open(params.conn)
      :ok = Channel.close(chann)
    end

    test "connects, creates multiple channels and disconnects", params do
      {:ok, chan1} = Channel.open(params.conn)
      {:ok, chan2} = Channel.open(params.conn)
      :ok = Channel.close(chan1)
      :ok = Channel.close(chan2)
    end

    test "a channel is gone along with the connection", params do
      {:ok, chann} = Channel.open(params.conn)
      :ok = Connection.close(params.conn)

      try do
        :ok = Channel.close(chann)
      catch
        :exit, {:noproc, _} ->
          :ok
      end
    end
  end
end
