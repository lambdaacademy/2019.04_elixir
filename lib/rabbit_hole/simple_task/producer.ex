defmodule RabbitHole.SimpleTask.Producer do
  @moduledoc """
  Simple task producer API
  """

  use GenServer
  require Logger
  alias RabbitHole.Protocol.{Connection, Channel, Queue, Basic}

  defstruct conn: nil, chan: nil, queue: nil
  alias __MODULE__, as: State

  @type producer_ref :: any()
  @type queue :: String.t
  @type message :: String.t

  # API

  @spec start(queue()) :: {:ok, producer_ref()}
  def start(queue) do
    GenServer.start(__MODULE__, queue)
  end

  @spec stop(producer_ref()) :: :ok
  def stop(ref) do
    GenServer.stop(ref)
  end

  @spec publish(producer_ref(), message()) :: :ok
  def publish(ref, message) do
    GenServer.cast(ref, {:publish, message})
  end

  # CALLBACKS

  def init(queue) do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {:ok, _} = Queue.declare(chan, queue)
    {:ok, %State{conn: conn, chan: chan, queue: queue}}
  end

  def terminate(_reason, state) do
    {:ok, %{message_count: cnt}} = Queue.delete(state.chan, state.queue)
    Logger.info("Deleted the #{state.queue} with #{cnt} messages")
    :ok = Channel.close(state.chan)
    :ok = Connection.close(state.conn)
  end

  def handle_cast({:publish, message}, state) do
    :ok = Basic.publish(state.chan, "", state.queue, message)
    {:noreply, state}
  end

end
