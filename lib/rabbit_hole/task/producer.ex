defmodule RabbitHole.Task.Producer do
  @moduledoc """
  Simple task producer API
  """

  use GenServer
  require Logger

  alias RabbitHole.Protocol.{Connection, Channel, Exchange, Basic}
  alias RabbitHole.Task

  @type producer_ref :: any()
  @type exchange :: Exchange.t()
  @type message :: String.t()

  # API

  @spec start(Exchange.t()) :: {:ok, producer_ref()}
  def start(exchange) do
  end

  @spec stop(producer_ref()) :: :ok
  def stop(ref) do
  end

  @spec publish(producer_ref(), Task.t(), [Basic.publish_opt()]) :: :ok
  def publish(ref, task, opts \\ []) do
  end

end
