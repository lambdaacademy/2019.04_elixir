defmodule RabbitHole.Producer do
  @moduledoc """
  Producer API
  """
  @type producer_ref :: any()
  @type queue :: String.t
  @type message :: String.t

  @spec start(queue()) :: {:ok, producer_ref()}
  def start(queue) do
    # start the producer as a separate process and return its pid as reference
    # declare (assert) the queue
  end

  @spec stop(producer_ref()) :: :ok
  def stop(ref) do
    # stop the producer given its reference, usually a pid
  end

  @spec publish(producer_ref(), message()) :: :ok
  def publish(ref, message) do
    # send a message to the task queue
  end
end
