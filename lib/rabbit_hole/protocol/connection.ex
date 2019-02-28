defmodule RabbitHole.Protocol.Connection do
  @moduledoc """
  Manages connections to RabbitMQ server.
  """

  alias AMQP.Connection

  @spec open(binary() | keyword()) :: {:error, any()} | {:ok, AMQP.Connection.t()}
  def open(opts \\ []) do
    Connection.open(opts)
  end

  @spec close(AMQP.Connection.t()) :: :ok | {:error, any()}
  def close(conn) do
    Connection.close(conn)
  end

end
