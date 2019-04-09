defmodule RabbitHole.Task.Consumer do
  @moduledoc """
  Simple task consumer API
  """

  use GenServer
  require Logger
  alias RabbitHole.Protocol.{Connection, Channel, Queue, Basic}
  alias RabbitHole.Task

  defstruct conn: nil,
            chan: nil,
            binding_key: nil,
            consumer_tag: nil,
            consumer_ref: nil,
            processor: nil

  alias __MODULE__, as: State

  @type consumer_ref :: any()
  @type processor :: (Task.t(), consumer_ref -> :ok | :error)
  @type opts() :: [processor: processor()]

  # API

  @spec start(Exchange.t(), Task.kind(), opts()) :: {:ok, consumer_ref()}
  def start(task_exchange, task_kind, opts \\ []) do
    binding_key = Task.topic(task_kind)
    GenServer.start(__MODULE__, [{:exchange, task_exchange}, {:binding_key, binding_key} | opts])
  end

  @spec stop(consumer_ref()) :: :ok
  def stop(ref) do
    GenServer.stop(ref)
  end

  # CALLBACKS

  def init(opts) do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {:ok, queue} = Queue.declare(chan, "", [:auto_delete])
    :ok = Queue.bind(chan, queue, opts[:exchange], routing_key: opts[:binding_key])
    {:ok, tag} = Basic.consume(chan, queue)

    {:ok,
     %State{
       conn: conn,
       chan: chan,
       binding_key: opts[:queue],
       consumer_tag: tag,
       consumer_ref: self(),
       processor: opts[:processor] || (&default_processor/1)
     }}
  end

  def handle_info({:basic_deliver, message, _meta}, state) do
    state.processor.(Task.from_message(message), state.consumer_ref)
    Logger.info("Processed message: #{inspect(message)}")
    {:noreply, state}
  end

  def terminate(_reason, state) do
    {:ok, _} = Basic.cancel(state.chan, state.consumer_tag)
    :ok = Channel.close(state.chan)
    :ok = Connection.close(state.conn)
  end

  # HELPERS

  defp default_processor(msg), do: IO.puts("Got message: #{inspect(msg)}")
end
