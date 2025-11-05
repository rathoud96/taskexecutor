defmodule Taskexecutor.Jobs.SorterTest do
  use ExUnit.Case, async: true

  alias Taskexecutor.Jobs.{Job, Sorter, Task}

  describe "build_graph/1" do
    test "builds graph from tasks" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: []},
        %Task{name: "task-2", command: "echo 2", requires: ["task-1"]}
      ]

      graph = Sorter.build_graph(tasks)

      assert Map.has_key?(graph, "task-1")
      assert Map.has_key?(graph, "task-2")
      assert MapSet.size(graph["task-1"]) == 0
      assert MapSet.member?(graph["task-2"], "task-1")
    end

    test "handles tasks with multiple dependencies" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: []},
        %Task{name: "task-2", command: "echo 2", requires: []},
        %Task{name: "task-3", command: "echo 3", requires: ["task-1", "task-2"]}
      ]

      graph = Sorter.build_graph(tasks)

      assert MapSet.size(graph["task-3"]) == 2
      assert MapSet.member?(graph["task-3"], "task-1")
      assert MapSet.member?(graph["task-3"], "task-2")
    end

    test "handles tasks with no dependencies" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: []}
      ]

      graph = Sorter.build_graph(tasks)

      assert MapSet.size(graph["task-1"]) == 0
    end
  end

  describe "detect_cycles/2" do
    test "returns ok when no cycles exist" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: []},
        %Task{name: "task-2", command: "echo 2", requires: ["task-1"]}
      ]

      graph = Sorter.build_graph(tasks)

      assert :ok = Sorter.detect_cycles(graph, tasks)
    end

    test "detects simple cycle" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: ["task-2"]},
        %Task{name: "task-2", command: "echo 2", requires: ["task-1"]}
      ]

      graph = Sorter.build_graph(tasks)

      assert {:error, error_msg} = Sorter.detect_cycles(graph, tasks)
      assert error_msg =~ "circular dependency"
    end

    test "detects longer cycle" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: ["task-2"]},
        %Task{name: "task-2", command: "echo 2", requires: ["task-3"]},
        %Task{name: "task-3", command: "echo 3", requires: ["task-1"]}
      ]

      graph = Sorter.build_graph(tasks)

      assert {:error, error_msg} = Sorter.detect_cycles(graph, tasks)
      assert error_msg =~ "circular dependency"
    end

    test "detects self-referential dependency" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: ["task-1"]}
      ]

      graph = Sorter.build_graph(tasks)

      assert {:error, error_msg} = Sorter.detect_cycles(graph, tasks)
      assert error_msg =~ "circular dependency"
    end
  end

  describe "topological_sort_recursive/2" do
    test "sorts simple linear dependencies" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: []},
        %Task{name: "task-2", command: "echo 2", requires: ["task-1"]},
        %Task{name: "task-3", command: "echo 3", requires: ["task-2"]}
      ]

      graph = Sorter.build_graph(tasks)
      sorted = Sorter.topological_sort_recursive(graph, tasks)

      assert length(sorted) == 3
      assert Enum.at(sorted, 0).name == "task-1"
      assert Enum.at(sorted, 1).name == "task-2"
      assert Enum.at(sorted, 2).name == "task-3"
    end

    test "sorts tasks with no dependencies" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: []},
        %Task{name: "task-2", command: "echo 2", requires: []},
        %Task{name: "task-3", command: "echo 3", requires: []}
      ]

      graph = Sorter.build_graph(tasks)
      sorted = Sorter.topological_sort_recursive(graph, tasks)

      assert length(sorted) == 3
      # All tasks have no dependencies, order may vary but all should be present
      sorted_names = Enum.map(sorted, & &1.name)
      assert "task-1" in sorted_names
      assert "task-2" in sorted_names
      assert "task-3" in sorted_names
    end

    test "sorts complex dependency graph" do
      tasks = [
        %Task{name: "task-1", command: "echo 1", requires: []},
        %Task{name: "task-2", command: "echo 2", requires: ["task-1"]},
        %Task{name: "task-3", command: "echo 3", requires: ["task-1"]},
        %Task{name: "task-4", command: "echo 4", requires: ["task-2", "task-3"]}
      ]

      graph = Sorter.build_graph(tasks)
      sorted = Sorter.topological_sort_recursive(graph, tasks)

      assert length(sorted) == 4
      assert Enum.at(sorted, 0).name == "task-1"
      # task-2 and task-3 can be in any order after task-1
      second_third = Enum.slice(sorted, 1, 2) |> Enum.map(& &1.name)
      assert "task-2" in second_third
      assert "task-3" in second_third
      assert Enum.at(sorted, 3).name == "task-4"
    end

    test "sorts example from requirements correctly" do
      tasks = [
        %Task{name: "task-1", command: "touch /tmp/file1", requires: []},
        %Task{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
        %Task{name: "task-3", command: "echo 'Hello World!' > /tmp/file1", requires: ["task-1"]},
        %Task{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
      ]

      graph = Sorter.build_graph(tasks)
      sorted = Sorter.topological_sort_recursive(graph, tasks)

      assert length(sorted) == 4

      sorted_names = Enum.map(sorted, & &1.name)

      # task-1 must come first (no dependencies)
      assert Enum.at(sorted_names, 0) == "task-1"

      # task-3 must come after task-1
      task3_index = Enum.find_index(sorted_names, &(&1 == "task-3"))
      assert task3_index > 0

      # task-2 must come after task-3
      task2_index = Enum.find_index(sorted_names, &(&1 == "task-2"))
      assert task2_index > task3_index

      # task-4 must come last (depends on task-2 and task-3)
      assert Enum.at(sorted_names, 3) == "task-4"
    end
  end

  describe "sort/1" do
    test "sorts job tasks correctly" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo 1", requires: []},
          %Task{name: "task-2", command: "echo 2", requires: ["task-1"]}
        ]
      }

      assert {:ok, sorted} = Sorter.sort(job)
      assert length(sorted) == 2
      assert Enum.at(sorted, 0).name == "task-1"
      assert Enum.at(sorted, 1).name == "task-2"
    end

    test "returns error when circular dependency detected" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo 1", requires: ["task-2"]},
          %Task{name: "task-2", command: "echo 2", requires: ["task-1"]}
        ]
      }

      assert {:error, error_msg} = Sorter.sort(job)
      assert error_msg =~ "circular dependency"
    end

    test "returns error for invalid job" do
      assert {:error, "invalid job struct"} = Sorter.sort(%{tasks: []})
    end

    test "sorts example from requirements" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "touch /tmp/file1", requires: []},
          %Task{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
          %Task{name: "task-3", command: "echo 'Hello World!' > /tmp/file1", requires: ["task-1"]},
          %Task{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
        ]
      }

      assert {:ok, sorted} = Sorter.sort(job)
      assert length(sorted) == 4

      sorted_names = Enum.map(sorted, & &1.name)

      # Expected order: task-1, task-3, task-2, task-4
      assert Enum.at(sorted_names, 0) == "task-1"
      assert Enum.at(sorted_names, 1) == "task-3"
      assert Enum.at(sorted_names, 2) == "task-2"
      assert Enum.at(sorted_names, 3) == "task-4"
    end
  end
end
