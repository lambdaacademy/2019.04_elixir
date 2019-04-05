defmodule RabbitHole.SimpleTask.Consumer do
  @moduledoc """
  Simple task consumer API
  """

  use GenServer
  require Logger
  alias RabbitHole.Protocol.{Connection, Channel, Queue, Basic}

  defstruct conn: nil, chan: nil, queue: nil, consumer_tag: nil, processor: nil
  alias __MODULE__, as: State

  @type consumer_ref :: any()
  @type processor :: (any() -> :ok | :error)
  @type opts() :: [processor: processor()]

  # API

  @spec start(any(), opts()) :: {:ok, consumer_ref()}
  def start(queue, opts \\ []) do
    GenServer.start(__MODULE__, [{:queue, queue} | opts])
  end

  @spec stop(consumer_ref()) :: :ok
  def stop(ref) do
    GenServer.stop(ref)
  end

  # CALLBACKS

  def init(opts) do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {:ok, _} = Queue.declare(chan, opts[:queue])
    {:ok, tag} = Basic.consume(chan, opts[:queue])

    {:ok,
     %State{
       conn: conn,
       chan: chan,
       queue: opts[:queue],
       consumer_tag: tag,
       processor: opts[:processor] || &default_processor/1
     }}
  end

  def handle_info({:basic_deliver, message, _meta}, state) do
    state.processor.(message)
    Logger.info("Processed message: #{inspect message}")
    {:noreply, state}
  end

  def terminate(_reason, state) do
    {:ok, _} = Basic.cancel(state.chan, state.consumer_tag)
    :ok = Channel.close(state.chan)
    :ok = Connection.close(state.conn)
  end

  # HELPERS

  defp default_processor(msg), do: IO.puts("Got message: #{inspect msg}")

end
