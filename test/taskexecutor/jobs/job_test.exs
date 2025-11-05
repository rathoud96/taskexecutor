defmodule Taskexecutor.Jobs.JobTest do
  use ExUnit.Case, async: true

  alias Taskexecutor.Jobs.{Job, Task}

  describe "new/1" do
    test "creates a valid job with tasks" do
      attrs = %{
        tasks: [
          %{name: "task-1", command: "echo hello"},
          %{name: "task-2", command: "echo world"}
        ]
      }

      assert {:ok, %Job{tasks: tasks}} = Job.new(attrs)
      assert length(tasks) == 2
      assert %Task{name: "task-1"} = Enum.find(tasks, &(&1.name == "task-1"))
      assert %Task{name: "task-2"} = Enum.find(tasks, &(&1.name == "task-2"))
    end

    test "creates a job with empty tasks list" do
      attrs = %{tasks: []}

      assert {:ok, %Job{tasks: []}} = Job.new(attrs)
    end

    test "accepts string keys" do
      attrs = %{
        "tasks" => [
          %{"name" => "task-1", "command" => "echo hello"}
        ]
      }

      assert {:ok, %Job{tasks: [%Task{name: "task-1"}]}} = Job.new(attrs)
    end

    test "returns error when tasks is not a list" do
      attrs = %{tasks: "not-a-list"}

      assert {:error, "tasks must be a list"} = Job.new(attrs)
    end

    test "returns error when attrs is not a map" do
      assert {:error, "attributes must be a map"} = Job.new("not-a-map")
      assert {:error, "attributes must be a map"} = Job.new([])
    end

    test "filters out invalid tasks" do
      attrs = %{
        tasks: [
          %{name: "task-1", command: "echo hello"},
          %{name: "task-2"}, # missing command
          %{name: "task-3", command: "echo world"}
        ]
      }

      assert {:ok, %Job{tasks: tasks}} = Job.new(attrs)
      assert length(tasks) == 2
      assert %Task{name: "task-1"} = Enum.find(tasks, &(&1.name == "task-1"))
      assert %Task{name: "task-3"} = Enum.find(tasks, &(&1.name == "task-3"))
    end
  end

  describe "validate/1" do
    test "returns ok for valid job" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo hello", requires: []},
          %Task{name: "task-2", command: "echo world", requires: []}
        ]
      }

      assert :ok = Job.validate(job)
    end

    test "returns error when tasks contain invalid structs" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo hello", requires: []},
          %{name: "task-2", command: "echo world"}
        ]
      }

      assert {:error, "all tasks must be valid Task structs"} = Job.validate(job)
    end

    test "returns error for invalid struct" do
      assert {:error, "invalid job struct"} = Job.validate(%{tasks: []})
    end
  end

  describe "validate_task_references/1" do
    test "returns ok when all task references exist" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo 1", requires: []},
          %Task{name: "task-2", command: "echo 2", requires: ["task-1"]},
          %Task{name: "task-3", command: "echo 3", requires: ["task-1", "task-2"]}
        ]
      }

      assert :ok = Job.validate_task_references(job)
    end

    test "returns ok when no tasks have requirements" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo 1", requires: []},
          %Task{name: "task-2", command: "echo 2", requires: []}
        ]
      }

      assert :ok = Job.validate_task_references(job)
    end

    test "returns error when a referenced task does not exist" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo 1", requires: ["missing-task"]}
        ]
      }

      assert {:error, "task 'missing-task' is referenced but does not exist"} =
               Job.validate_task_references(job)
    end

    test "returns error for multiple missing references" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo 1", requires: ["missing-1", "missing-2"]}
        ]
      }

      # Should return error for the first missing reference found
      assert {:error, "task 'missing-1' is referenced but does not exist"} =
               Job.validate_task_references(job)
    end

    test "returns error for invalid job struct" do
      assert {:error, "invalid job struct"} = Job.validate_task_references(%{tasks: []})
    end

    test "handles duplicate task names in requires" do
      job = %Job{
        tasks: [
          %Task{name: "task-1", command: "echo 1", requires: []},
          %Task{name: "task-2", command: "echo 2", requires: ["task-1", "task-1"]}
        ]
      }

      # Should still validate correctly
      assert :ok = Job.validate_task_references(job)
    end
  end

  describe "integration: task creation and validation" do
    test "creates and validates a complete job with dependencies" do
      attrs = %{
        tasks: [
          %{name: "task-1", command: "touch /tmp/file1"},
          %{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
          %{name: "task-3", command: "echo 'Hello World!' > /tmp/file1", requires: ["task-1"]},
          %{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
        ]
      }

      assert {:ok, job} = Job.new(attrs)
      assert :ok = Job.validate(job)
      assert :ok = Job.validate_task_references(job)
      assert length(job.tasks) == 4
    end

    test "detects duplicate task names" do
      attrs = %{
        tasks: [
          %{name: "task-1", command: "echo 1"},
          %{name: "task-1", command: "echo 2"} # duplicate name
        ]
      }

      # Job creation should succeed (duplicates are allowed in struct)
      # But validation should catch if we add that check
      assert {:ok, job} = Job.new(attrs)
      assert length(job.tasks) == 2
      # Both tasks have the same name, which is allowed at struct level
      # but might cause issues in sorting (to be handled in Phase 2)
    end
  end
end
