defmodule Taskexecutor.Jobs do
  @moduledoc """
  Context module for job processing operations.

  This module orchestrates the validation and sorting of job tasks,
  providing a clean interface for the HTTP layer.
  """

  alias Taskexecutor.Jobs.{Job, Sorter}

  alias Taskexecutor.Jobs.Task

  @type task_map :: %{String.t() => String.t() | list(String.t())}
  @type job_data :: %{tasks: list(task_map())}
  @type process_result :: {:ok, list(Task.t())} | {:error, String.t()}

  @doc """
  Processes a job by validating and sorting tasks.

  Accepts a map with job data (typically from JSON), validates it,
  and returns sorted tasks ready for execution.

  ## Examples

      iex> job_data = %{
      ...>   tasks: [
      ...>     %{name: "task-1", command: "echo hello"},
      ...>     %{name: "task-2", command: "echo world", requires: ["task-1"]}
      ...>   ]
      ...> }
      iex> Jobs.process(job_data)
      {:ok, [%Taskexecutor.Jobs.Task{name: "task-1"}, ...]}

      iex> Jobs.process(%{tasks: [%{name: "task-1"}]})
      {:error, "command is required"}
  """
  @spec process(job_data()) :: process_result()
  def process(%{tasks: tasks}) when is_list(tasks) do
    with :ok <- validate_all_tasks(tasks),
         {:ok, job} <- build_job(tasks),
         :ok <- validate_job(job) do
      sort_job(job)
    end
  end

  def process(%{tasks: _tasks}) do
    {:error, "tasks must be a list"}
  end

  def process(_), do: {:error, "invalid job data: tasks field is required"}

  defp validate_all_tasks(tasks) do
    tasks
    |> Enum.reduce_while(:ok, fn task_attrs, _acc ->
      case Taskexecutor.Jobs.Task.new(task_attrs) do
        {:ok, _task} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp build_job(tasks) do
    case Job.new(%{tasks: tasks}) do
      {:ok, job} -> {:ok, job}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_job(job) do
    with :ok <- Job.validate(job),
         :ok <- Job.validate_task_references(job) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp sort_job(job) do
    case Sorter.sort(job) do
      {:ok, sorted} -> {:ok, sorted}
      {:error, reason} -> {:error, reason}
    end
  end
end
