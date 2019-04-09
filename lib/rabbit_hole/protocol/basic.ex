defmodule RabbitHole.Protocol.Basic do
  @moduledoc """
  Provides methods of the AMQP Basic class.
  """

  @type publish_opt() :: :mandatory | atom()

  @allowed_opts [:mandatory]

  alias AMQP.Basic, as: B

  def publish(channel, exchange, routing_key, payload, opts \\ []) do
    B.publish(channel, exchange, routing_key, payload, check_opts(opts))
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

  ### HELPERS

  defp check_opts([]), do: []
  defp check_opts(opts) do
    Enum.map(opts, fn
      o when o in @allowed_opts -> {o, true}
      o -> raise "Unreconginsed option: #{o}"
    end)
  end
end
