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
            manual_ack: false,
            binding_key: nil,
            consumer_tag: nil,
            consumer_ref: nil,
            processor: nil

  alias __MODULE__, as: State

  @type consumer_ref :: any()
  @type processor :: (Task.t(), consumer_ref -> :ok | :error)
  @type opts() :: [processor: processor(), prefetch: non_neg_integer()]

  # API

  @spec start(Exchange.t(), Task.kind(), opts()) :: {:ok, consumer_ref()}
  def start(task_exchange, task_kind, opts \\ []) do
    binding_key = Task.topic(task_kind)
    verify_opts!(opts)

    GenServer.start(
      __MODULE__,
      [{:exchange, task_exchange}, {:binding_key, binding_key} | opts]
    )
  end

  @spec stop(consumer_ref()) :: :ok
  def stop(ref, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop(ref, reason, timeout)
  end

  # CALLBACKS

  def init(opts) do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    {:ok, queue} = Queue.declare(chan, "", [:auto_delete])
    :ok = Queue.bind(chan, queue, opts[:exchange], routing_key: opts[:binding_key])

    {:ok, tag} =
      if opts[:prefetch] do
        :ok = Basic.qos(chan, prefetch_count: opts[:prefetch])
        Basic.consume(chan, queue, no_ack: false)
      else
        Basic.consume(chan, queue, no_ack: true)
      end

    {:ok,
     %State{
       conn: conn,
       chan: chan,
       manual_ack: (opts[:prefetch] && true) || false,
       binding_key: opts[:queue],
       consumer_tag: tag,
       consumer_ref: self(),
       processor: opts[:processor] || (&default_processor/1)
     }}
  end

  def handle_info({:basic_deliver, message, _meta}, %State{manual_ack: false} = state) do
    state.processor.(Task.from_message(message), state.consumer_ref)
    Logger.debug("Processed message: #{inspect(Task.from_message(message))}")
    {:noreply, state}
  end

  def handle_info({:basic_deliver, message, meta}, %State{manual_ack: true} = state) do
    state.processor.(Task.from_message(message), state.consumer_ref)
    Basic.ack(state.chan, meta.delivery_tag)
    Logger.debug("Processed message: #{inspect(Task.from_message(message))}")
    {:noreply, state}
  end

  def terminate(_reason, state) do
    {:ok, _} = Basic.cancel(state.chan, state.consumer_tag)
    :ok = Channel.close(state.chan)
    :ok = Connection.close(state.conn)
  end

  # HELPERS

  defp default_processor(msg), do: IO.puts("Got message: #{inspect(msg)}")

  defp verify_opts!(opts) do
    if opts[:prefetch] do
      (is_integer(opts[:prefetch]) && opts[:prefetch] > 0) ||
        raise "Bad value for :prefetch: #{inspect(opts[:prefetch])}"
    end
  end
end
