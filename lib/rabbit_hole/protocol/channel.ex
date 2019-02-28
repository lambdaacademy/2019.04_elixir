defmodule RabbitHole.Protocol.Channel do
  @moduledoc """
  Manages channels to RabbitMQ server.
  """

  alias AMQP.Channel

  @spec open(AMQP.Connection.t()) :: {:error, any()} | {:ok, AMQP.Channel.t()}
  def open(conn) do
    Channel.open(conn)
  end

  @spec close(AMQP.Channel.t()) :: :ok | {:error, any()}
  def close(channel) do
    Channel.close(channel)
  end
end
