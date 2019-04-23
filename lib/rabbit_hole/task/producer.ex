defmodule RabbitHole.Task.Producer do
  @moduledoc """
  Simple task producer API
  """

  use GenServer
  require Logger

  alias RabbitHole.Protocol.{Connection, Channel, Exchange, Basic, Confirm}
  alias RabbitHole.Task

  defstruct conn: nil,
            chan: nil,
            exchange: nil,
            confirms: false,
            max_unconfirmed: 0,
            unconfirmed: [],
            confirm_callbacks: %{}

  alias __MODULE__, as: State

  @type producer_ref :: any()
  @type exchange :: Exchange.t()
  @type message :: String.t()
  @type start_opts :: [confirms: boolean(), max_unconfirmed: integer()]
  @type publish_opts :: [confirm_callback: (publish_ref() -> any()) | Basic.publish_opt()]
  @type publish_ref :: reference()
  @type publish_ret ::
          {:ok, publish_ref()}
          | {:rejected, :all}
          | {:rejected, publish_ref(), {:over_limit, pos_integer()}}

  # API

  @spec start(Exchange.t(), start_opts()) :: {:ok, producer_ref()}
  def start(exchange, opts \\ []) do
    verify_opts!(opts)
    GenServer.start(__MODULE__, [{:exchange, exchange} | opts])
  end

  @spec stop(producer_ref()) :: :ok
  def stop(ref) do
    GenServer.stop(ref)
  end

  @spec publish(producer_ref(), Task.t() | [Task.t()], publish_opts()) :: publish_ret()
  def publish(ref, task_or_tasks, opts \\ [])

  def publish(ref, tasks, opts) when is_list(tasks) do
    nil
  end

  def publish(ref, task, opts) do
    routing_key = Task.topic(task)
    GenServer.cast(ref, {:publish, task, routing_key, opts})
  end

  # CALLBACKS

  @spec init(Keyword.t()) :: {:ok, RabbitHole.Task.Producer.t()}
  def init(opts) do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)
    :ok = Exchange.declare(chan, opts[:exchange], :topic)
    {:ok, %State{conn: conn, chan: chan, exchange: opts[:exchange]}}
  end

  def terminate(_reason, state) do
    :ok = Channel.close(state.chan)
    :ok = Connection.close(state.conn)
  end

  defp verify_opts!(opts) do
    if opts[:confirms] do
      (is_integer(opts[:max_unconfirmed]) && opts[:max_unconfirmed] > 0) ||
        raise "Bad value for :max_unconfirmed: #{inspect(opts[:max_unconfirmed])}"
    end
  end

  end
end
