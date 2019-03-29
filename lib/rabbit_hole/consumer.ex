defmodule RabbitHole.Consumer do
  @moduledoc """
  Consumer API
  """

  @type consumer_ref :: any()
  @type processor :: (any() -> :ok | :error)
  @type opts() :: [processor: processor()]

  @spec start(any(), opts()) :: {:ok, consumer_ref()}
  def start(queue, opts \\ [])  do
    # start the consumer as a separate process and return its pid as reference
    # declare (assert) the queue
    # consume messages from the queue and pass on to the processor fun
  end

  @spec stop(consumer_ref()) :: :ok
  def stop(ref) do
  # stop the consumer given its reference, usually a pid
  end

end
