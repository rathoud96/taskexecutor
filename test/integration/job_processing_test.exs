defmodule Taskexecutor.Integration.JobProcessingTest do
  use ExUnit.Case, async: false

  alias Taskexecutor.Jobs

  describe "end-to-end job processing" do
    test "example from requirements produces correct JSON output" do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "touch /tmp/file1"},
          %{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
          %{name: "task-3", command: "echo 'Hello World!' > /tmp/file1", requires: ["task-1"]},
          %{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
        ]
      }

      assert {:ok, sorted_tasks} = Jobs.process(job_data)

      # Verify correct order
      sorted_names = Enum.map(sorted_tasks, & &1.name)
      assert sorted_names == ["task-1", "task-3", "task-2", "task-4"]

      # Verify all tasks are present
      assert length(sorted_tasks) == 4

      # Verify task structure
      task1 = Enum.find(sorted_tasks, &(&1.name == "task-1"))
      assert task1.command == "touch /tmp/file1"
      assert task1.requires == []
    end

    test "example from requirements produces correct bash script output" do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "touch /tmp/file1"},
          %{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
          %{name: "task-3", command: "echo 'Hello World!' > /tmp/file1", requires: ["task-1"]},
          %{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
        ]
      }

      assert {:ok, sorted_tasks} = Jobs.process(job_data)

      script = Taskexecutor.Jobs.Formatter.to_bash_script(sorted_tasks)
      lines = String.split(script, "\n", trim: true)

      # Verify shebang
      assert List.first(lines) == "#!/usr/bin/env bash"

      # Verify commands in correct order
      assert Enum.at(lines, 1) == "touch /tmp/file1"
      assert Enum.at(lines, 2) == "echo 'Hello World!' > /tmp/file1"
      assert Enum.at(lines, 3) == "cat /tmp/file1"
      assert Enum.at(lines, 4) == "rm /tmp/file1"
    end

    test "handles complex dependency graph correctly" do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1"},
          %{name: "task-2", command: "echo 2", requires: ["task-1"]},
          %{name: "task-3", command: "echo 3", requires: ["task-1"]},
          %{name: "task-4", command: "echo 4", requires: ["task-2", "task-3"]},
          %{name: "task-5", command: "echo 5", requires: ["task-4"]}
        ]
      }

      assert {:ok, sorted_tasks} = Jobs.process(job_data)

      sorted_names = Enum.map(sorted_tasks, & &1.name)

      # task-1 must come first
      assert Enum.at(sorted_names, 0) == "task-1"

      # task-5 must come last
      assert Enum.at(sorted_names, 4) == "task-5"

      # task-2 and task-3 must come after task-1 but before task-4
      task1_index = Enum.find_index(sorted_names, &(&1 == "task-1"))
      task2_index = Enum.find_index(sorted_names, &(&1 == "task-2"))
      task3_index = Enum.find_index(sorted_names, &(&1 == "task-3"))
      task4_index = Enum.find_index(sorted_names, &(&1 == "task-4"))

      assert task2_index > task1_index
      assert task3_index > task1_index
      assert task4_index > task2_index
      assert task4_index > task3_index
    end

    test "detects circular dependencies" do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1", requires: ["task-2"]},
          %{name: "task-2", command: "echo 2", requires: ["task-1"]}
        ]
      }

      assert {:error, reason} = Jobs.process(job_data)
      assert reason =~ "circular dependency"
    end

    test "detects missing task references" do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1", requires: ["missing-task"]}
        ]
      }

      assert {:error, reason} = Jobs.process(job_data)
      assert reason =~ "is referenced but does not exist"
    end

    test "validates required fields" do
      job_data = %{
        tasks: [
          %{name: "task-1"} # missing command
        ]
      }

      assert {:error, reason} = Jobs.process(job_data)
      assert reason =~ "command is required"
    end
  end
end
