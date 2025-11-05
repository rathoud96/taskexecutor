defmodule Taskexecutor.Jobs.Sorter do
  @moduledoc """
  Provides functions for sorting tasks based on their dependencies using
  recursive topological sort.

  For each task, recursively sorts its dependencies first, then adds the task.
  This approach is simpler and easier to understand than Kahn's algorithm.
  """

  alias Taskexecutor.Jobs.{Job, Task}

  @type task_name :: String.t()
  @type dependency_graph :: %{task_name() => MapSet.t(task_name())}
  @type sort_result :: {:ok, list(Task.t())} | {:error, String.t()}

  @doc """
  Sorts tasks in a job based on their dependencies using recursive DFS.

  Returns `{:ok, sorted_tasks}` where tasks are ordered such that all
  dependencies are satisfied before dependent tasks, or `{:error, reason}`
  if circular dependencies are detected.

  ## Examples

      iex> job = %Taskexecutor.Jobs.Job{tasks: [
      ...>   %Taskexecutor.Jobs.Task{name: "task-1", command: "echo 1", requires: []},
      ...>   %Taskexecutor.Jobs.Task{name: "task-2", command: "echo 2", requires: ["task-1"]}
      ...> ]}
      iex> Sorter.sort(job)
      {:ok, [%Taskexecutor.Jobs.Task{name: "task-1"}, %Taskexecutor.Jobs.Task{name: "task-2"}]}
  """
  @spec sort(Job.t()) :: sort_result()
  def sort(%Job{tasks: tasks}) when is_list(tasks) do
    with graph <- build_graph(tasks),
         :ok <- detect_cycles(graph, tasks),
         sorted <- topological_sort_recursive(graph, tasks) do
      {:ok, sorted}
    end
  end

  def sort(_), do: {:error, "invalid job struct"}

  @doc """
  Builds a dependency graph from a list of tasks.

  The graph is represented as a map where keys are task names and values
  are sets of task names that this task depends on.
  """
  @spec build_graph(list(Task.t())) :: dependency_graph()
  def build_graph(tasks) do
    tasks
    |> Enum.reduce(%{}, fn task, acc ->
      Map.put(acc, task.name, MapSet.new(task.requires))
    end)
  end

  @doc """
  Detects circular dependencies in the dependency graph.

  Returns `:ok` if no cycles are found, or `{:error, reason}` if a cycle
  is detected.

  ## Examples

      iex> graph = %{"task-1" => MapSet.new(["task-2"]), "task-2" => MapSet.new(["task-1"])}
      iex> Sorter.detect_cycles(graph, [])
      {:error, "circular dependency detected"}
  """
  @spec detect_cycles(dependency_graph(), list(Task.t())) :: :ok | {:error, String.t()}
  def detect_cycles(graph, tasks) do
    task_names = MapSet.new(Enum.map(tasks, & &1.name))

    case find_cycle(graph, task_names) do
      nil -> :ok
      cycle -> {:error, "circular dependency detected: #{format_cycle(cycle)}"}
    end
  end

  @doc """
  Performs topological sort using recursive DFS.

  For each task:
  1. Recursively sort all its dependencies first
  2. Then add the task itself
  3. Use visited set to avoid duplicates
  """
  @spec topological_sort_recursive(dependency_graph(), list(Task.t())) :: list(Task.t())
  def topological_sort_recursive(graph, tasks) do
    task_map = Map.new(tasks, fn task -> {task.name, task} end)
    task_names = MapSet.new(Enum.map(tasks, & &1.name))
    visited = MapSet.new()

    task_names
    |> MapSet.to_list()
    |> Enum.reduce({[], visited}, fn task_name, {acc_sorted, acc_visited} ->
      if MapSet.member?(acc_visited, task_name) do
        {acc_sorted, acc_visited}
      else
        {new_sorted, new_visited} =
          sort_dependencies_recursive(graph, task_name, task_map, acc_visited, [])

        {new_sorted ++ acc_sorted, new_visited}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # Recursively sorts dependencies of a task, then adds the task itself
  defp sort_dependencies_recursive(graph, task_name, task_map, visited, acc) do
    if MapSet.member?(visited, task_name) do
      {acc, visited}
    else
      # Get task's dependencies
      deps = Map.get(graph, task_name, MapSet.new())

      # First, recursively sort all dependencies
      {sorted_deps, new_visited} =
        deps
        |> MapSet.to_list()
        |> Enum.reduce({[], MapSet.put(visited, task_name)}, fn dep_name,
                                                                {acc_deps, acc_visited} ->
          {dep_sorted, dep_visited} =
            sort_dependencies_recursive(graph, dep_name, task_map, acc_visited, [])

          {dep_sorted ++ acc_deps, dep_visited}
        end)

      # Then add the task itself
      task = Map.fetch!(task_map, task_name)
      {[task | sorted_deps ++ acc], new_visited}
    end
  end

  defp find_cycle(graph, task_names) do
    task_names
    |> MapSet.to_list()
    |> Enum.reduce_while(nil, fn task_name, _acc ->
      visited = MapSet.new()
      rec_stack = MapSet.new()

      case dfs_cycle_detection(graph, task_name, visited, rec_stack) do
        {:cycle, cycle} -> {:halt, cycle}
        :no_cycle -> {:cont, nil}
      end
    end)
  end

  defp dfs_cycle_detection(graph, task_name, visited, rec_stack) do
    cond do
      MapSet.member?(visited, task_name) and not MapSet.member?(rec_stack, task_name) ->
        :no_cycle

      MapSet.member?(rec_stack, task_name) ->
        {:cycle, [task_name]}

      true ->
        check_dependencies_for_cycles(graph, task_name, visited, rec_stack)
    end
  end

  defp check_dependencies_for_cycles(graph, task_name, visited, rec_stack) do
    new_visited = MapSet.put(visited, task_name)
    new_rec_stack = MapSet.put(rec_stack, task_name)

    dependencies = Map.get(graph, task_name, MapSet.new())

    dependencies
    |> MapSet.to_list()
    |> Enum.reduce_while(:no_cycle, fn dep_name, _acc ->
      case dfs_cycle_detection(graph, dep_name, new_visited, new_rec_stack) do
        {:cycle, cycle} ->
          full_cycle = [task_name | cycle]
          {:halt, {:cycle, full_cycle}}

        :no_cycle ->
          {:cont, :no_cycle}
      end
    end)
    |> handle_cycle_result()
  end

  defp handle_cycle_result({:cycle, cycle}), do: {:cycle, cycle}
  defp handle_cycle_result(_), do: :no_cycle

  defp format_cycle(cycle) do
    cycle
    |> Enum.reverse()
    |> Enum.join(" -> ")
  end
end
