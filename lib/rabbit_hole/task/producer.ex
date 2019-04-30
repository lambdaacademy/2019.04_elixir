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
    Enum.each(tasks, &Task.assert_valid!(&1))
    GenServer.call(ref, {:publish, tasks, opts})
  end

  def publish(ref, task, opts) do
    Task.assert_valid!(task)
    GenServer.call(ref, {:publish, [task], opts})
  end

  # CALLBACKS

  @spec init(Keyword.t()) :: {:ok, RabbitHole.Task.Producer.t()}
  def init(opts) do
    {:ok, conn} = Connection.open()
    {:ok, chan} = Channel.open(conn)

    if opts[:max_unconfirmed] do
      :ok = Confirm.select(chan)
      :ok = Confirm.register_handler(chan)
    end

    :ok = Exchange.declare(chan, opts[:exchange], :topic)

    {:ok,
     %State{
       conn: conn,
       chan: chan,
       exchange: opts[:exchange],
       confirms: opts[:confirms] || false,
       max_unconfirmed: opts[:max_unconfirmed]
     }}
  end

  def terminate(_reason, state) do
    :ok = Channel.close(state.chan)
    :ok = Connection.close(state.conn)
  end

  def handle_call(
        {:publish, tasks, opts},
        _from,
        %State{confirms: true, max_unconfirmed: max, unconfirmed: unconfirmed} = state
      ) do
    cond do
      length(unconfirmed) == max ->
        {:reply, {:rejected, :all}, state}

      length(unconfirmed) < max ->
        {accepted, rejected} = split_tasks(tasks, length(unconfirmed), max)

        last_seq_no =
          publish(state.chan, state.exchange, accepted, Keyword.drop(opts, [:confirm_callback]))

        pub_ref = pub_ref()

        reply =
          if Enum.empty?(rejected) do
            {:ok, pub_ref}
          else
            {:rejected, pub_ref, {:over_limit, length(rejected)}}
          end

        {:reply, reply,
         %State{
           state
           | confirm_callbacks:
               maybe_store_confirm_callback(
                 opts[:confirm_callback],
                 last_seq_no,
                 pub_ref,
                 state.confirm_callbacks
               ),
             unconfirmed: append_unconfirmed(accepted, last_seq_no, state.unconfirmed)
         }}
    end
  end

  def handle_call({:publish, tasks, opts}, _from, %State{confirms: false} = state) do
    _ = publish(state.chan, state.exchange, tasks, opts)
    {:reply, :ok, state}
  end

  def handle_info(
        {:basic_ack, seqno, multiple},
        %State{unconfirmed: unconfirmed, confirm_callbacks: callbacks} = state
      ) do
    {:noreply,
     %State{
       state
       | unconfirmed: remove_unconfirmed(seqno, unconfirmed, multiple),
         confirm_callbacks: maybe_run_remove_confirm_callbacks(seqno, multiple, callbacks)
     }}
  end

  # INTERNALS

  defp verify_opts!(opts) do
    if opts[:confirms] do
      (is_integer(opts[:max_unconfirmed]) && opts[:max_unconfirmed] > 0) ||
        raise "Bad value for :max_unconfirmed: #{inspect(opts[:max_unconfirmed])}"
    end
  end

  defp publish(chan, exchange, [task], opts) do
    seqno = Confirm.next_publish_seqno(chan)
    routing_key = Task.topic(task)
    :ok = Basic.publish(chan, exchange, routing_key, Task.to_message(task), opts)
    seqno
  end

  defp publish(chan, exchange, [task | ts], opts) do
    routing_key = Task.topic(task)
    :ok = Basic.publish(chan, exchange, routing_key, Task.to_message(task), opts)
    publish(chan, exchange, ts, opts)
  end

  defp pub_ref(), do: make_ref()

  defp split_tasks(tasks, unconfirmed_cnt, max_unconfirmed) do
    Enum.split(tasks, max_unconfirmed - unconfirmed_cnt)
  end

  defp append_unconfirmed(tasks, last_seq_no, unconfirmed) do
    unconfirmed ++ Enum.to_list((last_seq_no - length(tasks) + 1)..last_seq_no)
  end

  defp remove_unconfirmed(seqno, unconfirmed, multiple?) do
    if multiple? do
      Enum.drop_while(unconfirmed, &(&1 <= seqno))
    else
      unconfirmed -- [seqno]
    end
  end

  defp maybe_store_confirm_callback(nil, _, _, callbacks), do: callbacks

  defp maybe_store_confirm_callback(confirm_callback, seqno, pub_ref, callbacks) do
    Map.put(callbacks, seqno, fn -> confirm_callback.(pub_ref) end)
  end

  defp maybe_run_remove_confirm_callbacks(confirm_seqno, multiple?, callbacks) do
    fun = fn
      {seqno, cb}, acc when multiple? == true and seqno <= confirm_seqno ->
        cb.()
        acc

      {seqno, cb}, acc when multiple? == false and seqno == confirm_seqno ->
        cb.()
        acc

      {seqno, cb}, acc ->
        Map.put(acc, seqno, cb)
    end

    Enum.reduce(callbacks, %{}, fun)
  end
end
