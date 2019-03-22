defmodule RabbitHole.Protocol.Basic do
  @moduledoc """
  Provides methods of the AMQP Basic class.
  """

  alias AMQP.Basic, as: B

  defdelegate publish(channel, exchange, routing_key, payload, options \\ []), to: B

  def consume(channel, queue, options \\ []) do
    B.consume(channel, queue, self(), options)
    receive do
      {:basic_consume_ok, %{consumer_tag: consumer_tag}} ->
        {:ok, consumer_tag}
    end
  end

end
