defmodule RabbitHole.Protocol.Basic do
  @moduledoc """
  Provides methods of the AMQP Basic class.
  """

  @type publish_opt() :: :mandatory | atom()

  @allowed_publish_opts [:mandatory]

  alias AMQP.Basic, as: B

  def publish(channel, exchange, routing_key, payload, opts \\ []) do
    B.publish(channel, exchange, routing_key, payload, check_opts(opts, @allowed_publish_opts))
  end

  def consume(channel, queue, options \\ []) do
    {:ok, consumer_tag} = B.consume(channel, queue, self(), options)

    receive do
      {:basic_consume_ok, %{consumer_tag: ^consumer_tag}} ->
        {:ok, consumer_tag}
    end
  end

  def cancel(channel, consumer_tag, options \\ []) do
    {:ok, ^consumer_tag} = B.cancel(channel, consumer_tag, options)

    receive do
      {:basic_cancel_ok, %{consumer_tag: ^consumer_tag}} ->
        {:ok, consumer_tag}
    end
  end

  def ack(channel, delivery_tag, opts \\ []) do
    B.ack(channel, delivery_tag, check_opts(opts, [:multiple]))
  end

  defdelegate qos(channel, options), to: B

  ### HELPERS

  defp check_opts([], _), do: []

  defp check_opts(opts, allowed) do
    Enum.map(opts, fn o ->
      (o in allowed && {o, true}) || raise "Unreconginsed option: #{o}"
    end)
  end
end
