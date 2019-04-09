defmodule RabbitHole.Task do
  @type t :: Fun.t() | MFA.t() | Other.t()
  @type kind :: Fun | MFA | Other

  defmodule Fun do
    defstruct fun: nil, args: []
  end

  defmodule MFA do
    defstruct mod: nil, fun: nil, args: []
  end

  defmodule Other do
    defstruct val: nil
  end

  def topic_prefix(), do: "task."

  def topic(task_kind) when is_atom(task_kind) do
    topic_prefix() <> topic_suffix(task_kind)
  end
  def topic(%_{} = task) do
    valid_task?(task) || raise "Invalid task"
    %task_kind{} = task
    topic(task_kind)
  end

  def to_message(%_{} = task) do
    valid_task?(task) && :erlang.term_to_binary(task) || raise "Invalid task"
  end

  def from_message(task) when is_binary(task) do
    task = :erlang.binary_to_term(task)
    valid_task?(task) && task || raise "Invalid task"
  end

  defp topic_suffix(task_kind),
    do: task_kind |> Module.split() |> List.last() |> String.downcase()

  defp valid_task?(%Fun{}), do: true
  defp valid_task?(%MFA{}), do: true
  defp valid_task?(%Other{}), do: true
  defp valid_task?(_), do: false

end
