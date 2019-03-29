defmodule RabbitHole.Protocol.ConnectionTest do
  use ExUnit.Case

  alias RabbitHole.Protocol.{Connection, Channel}

  test "connects and creates a channel" do
    {:ok, conn} = Connection.open()
    {:ok, _chan} = Channel.open(conn)
  end

  test "connects, creates a channel and disconnects" do
    {:ok, conn} = Connection.open()
    {:ok, chann} = Channel.open(conn)
    :ok = Channel.close(chann)
    :ok = Connection.close(conn)
  end
end
