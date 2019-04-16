defmodule RabbitHole.Task.Producer do
  @moduledoc """
  Simple task producer API
  """

  use GenServer
  require Logger

  alias RabbitHole.Protocol.{Connection, Channel, Exchange, Basic}
  alias RabbitHole.Task

  defstruct conn: nil, chan: nil, exchange: nil
  alias __MODULE__, as: State

  @type producer_ref :: any()
  @type exchange :: Exchange.t()
  @type message :: String.t()

  # API

  @spec start(Exchange.t()) :: {:ok, producer_ref()}
  def start(exchange) do
    GenServer.start(__MODULE__, exchange)
  end

  @spec stop(producer_ref()) :: :ok
  def stop(ref) do
    GenServer.stop(ref)
  end

  @spec publish(producer_ref(), Task.t(), [Basic.publish_opt()]) :: :ok
  def publish(ref, task, opts \\ []) do
    routing_key = Task.topic(task)
    GenServer.cast(ref, {:publish, task, routing_key, opts})
  end

  # CALLBACKS

  @spec init(binary()) :: {:ok, RabbitHole.Task.Producer.t()}
  def init(exchange) do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    :ok = Exchange.declare(chan, exchange, :topic)
    {:ok, %State{conn: conn, chan: chan, exchange: exchange}}
  end

  def terminate(_reason, state) do
    :ok = Channel.close(state.chan)
    :ok = Connection.close(state.conn)
  end

  def handle_cast({:publish, task, routing_key, opts}, state) do
    :ok = Basic.publish(state.chan, state.exchange, routing_key, Task.to_message(task), opts)
    {:noreply, state}
  end
end
