defmodule Taskexecutor.Jobs.Job do
  @moduledoc """
  Defines the Job struct and validation logic for job definitions.

  A job contains a list of tasks that need to be executed in a specific order
  based on their dependencies.
  """

  alias Taskexecutor.Jobs.Task

  @type t :: %__MODULE__{
          tasks: list(Task.t())
        }

  @type validation_error :: {:error, String.t()}

  defstruct [:tasks]

  @doc """
  Creates a new job from a map of attributes.

  Returns `{:ok, job}` on success or `{:error, reason}` on validation failure.

  ## Examples

      iex> attrs = %{tasks: [%{name: "task-1", command: "echo hello"}]}
      iex> new(attrs)
      {:ok, %Taskexecutor.Jobs.Job{tasks: [...]}}

      iex> new(%{tasks: []})
      {:ok, %Taskexecutor.Jobs.Job{tasks: []}}
  """
  @spec new(map()) :: {:ok, t()} | validation_error()
  def new(attrs) when is_map(attrs) do
    with :ok <- validate_tasks(attrs) do
      tasks = build_tasks(attrs[:tasks] || attrs["tasks"] || [])
      job = %__MODULE__{tasks: tasks}
      {:ok, job}
    end
  end

  def new(_), do: {:error, "attributes must be a map"}

  @doc """
  Validates a job struct.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.
  """
  @spec validate(t()) :: :ok | validation_error()
  def validate(%__MODULE__{tasks: tasks}) when is_list(tasks) do
    if Enum.all?(tasks, &match?(%Task{}, &1)) do
      :ok
    else
      {:error, "all tasks must be valid Task structs"}
    end
  end

  def validate(_), do: {:error, "invalid job struct"}

  @doc """
  Validates that all task names referenced in `requires` arrays exist in the job.

  Returns `:ok` if all references are valid, or `{:error, reason}` if any
  task reference is missing.

  ## Examples

      iex> job = %Taskexecutor.Jobs.Job{tasks: [
      ...>   %Taskexecutor.Jobs.Task{name: "task-1", command: "echo 1", requires: []},
      ...>   %Taskexecutor.Jobs.Task{name: "task-2", command: "echo 2", requires: ["task-1"]}
      ...> ]}
      iex> validate_task_references(job)
      :ok

      iex> job = %Taskexecutor.Jobs.Job{tasks: [
      ...>   %Taskexecutor.Jobs.Task{name: "task-1", command: "echo 1", requires: ["missing-task"]}
      ...> ]}
      iex> validate_task_references(job)
      {:error, "task 'missing-task' is referenced but does not exist"}
  """
  @spec validate_task_references(t()) :: :ok | validation_error()
  def validate_task_references(%__MODULE__{tasks: tasks}) do
    task_names = MapSet.new(Enum.map(tasks, & &1.name))

    tasks
    |> Enum.reduce_while(:ok, fn task, _acc ->
      missing_references =
        task.requires
        |> Enum.filter(fn required_name -> not MapSet.member?(task_names, required_name) end)

      case missing_references do
        [] ->
          {:cont, :ok}

        [missing | _] ->
          {:halt, {:error, "task '#{missing}' is referenced but does not exist"}}
      end
    end)
  end

  def validate_task_references(_), do: {:error, "invalid job struct"}

  defp validate_tasks(attrs) do
    tasks = attrs[:tasks] || attrs["tasks"]

    if is_list(tasks) do
      :ok
    else
      {:error, "tasks must be a list"}
    end
  end

  defp build_tasks(tasks) when is_list(tasks) do
    tasks
    |> Enum.map(fn task_attrs ->
      case Task.new(task_attrs) do
        {:ok, task} -> task
        {:error, _reason} -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp build_tasks(_), do: []
end
