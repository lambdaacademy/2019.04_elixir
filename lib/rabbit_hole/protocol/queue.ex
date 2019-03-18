defmodule RabbitHole.Protocol.Queue do
  @moduledoc """
  Manages RabbitMQ queues
  """

  alias AMQP.Queue, as: Q

  @allowed_opts [:passive, :auto_delete, :exclusive, :durable, :nowait, :arguments]

  def declare(channel, name \\ "", opts \\ []) do
    {:ok, params} = Q.declare(channel, name, check_opts(opts))
    {:ok, params.queue}
  end

  def delete(channel, queue), do: Q.delete(channel, queue)

  ### HELPERS

  defp check_opts(opts) do
    Enum.map(opts, fn
      (o) when o in @allowed_opts -> {o, true}
      ({:arguments, args} = o) when is_list(args) -> o
      (o) -> raise "Unreconginsed option: #{o}"
    end)
  end
end
