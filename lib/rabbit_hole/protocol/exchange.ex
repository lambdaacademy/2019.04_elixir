defmodule RabbitHole.Protocol.Exchange do
  @moduledoc """
  Manages RabbitMQ exchanges
  """

  @type t :: String.t()

  alias AMQP.Exchange, as: E

  @allowed_opts [:passive, :auto_delete, :durable, :internal]

  @spec declare(AMQP.Channel.t(), binary(), atom(), any()) ::
          :ok | {:error, :blocked | :closing}
  def declare(channel, exchange, type \\ :direct, opts \\ []) do
    E.declare(channel, exchange, type, check_opts(opts))
  end

  defdelegate  delete(channel, exchange), to: E

  ### HELPERS

  defp check_opts(opts) do
    Enum.map(opts, fn
      o when o in @allowed_opts -> {o, true}
      o -> raise "Unreconginsed option: #{o}"
    end)
  end
end
