defmodule Taskexecutor.Jobs.TaskTest do
  use ExUnit.Case, async: true

  alias Taskexecutor.Jobs.Task

  describe "new/1" do
    test "creates a valid task with required fields" do
      attrs = %{name: "task-1", command: "echo hello"}

      assert {:ok, %Task{name: "task-1", command: "echo hello", requires: []}} = Task.new(attrs)
    end

    test "creates a task with requires field" do
      attrs = %{name: "task-1", command: "echo hello", requires: ["task-2", "task-3"]}

      assert {:ok, %Task{name: "task-1", command: "echo hello", requires: ["task-2", "task-3"]}} =
               Task.new(attrs)
    end

    test "accepts string keys" do
      attrs = %{"name" => "task-1", "command" => "echo hello", "requires" => ["task-2"]}

      assert {:ok, %Task{name: "task-1", command: "echo hello", requires: ["task-2"]}} =
               Task.new(attrs)
    end

    test "returns error when name is missing" do
      attrs = %{command: "echo hello"}

      assert {:error, "name is required"} = Task.new(attrs)
    end

    test "returns error when name is empty string" do
      attrs = %{name: "", command: "echo hello"}

      assert {:error, "name is required"} = Task.new(attrs)
    end

    test "returns error when command is missing" do
      attrs = %{name: "task-1"}

      assert {:error, "command is required"} = Task.new(attrs)
    end

    test "returns error when command is empty string" do
      attrs = %{name: "task-1", command: ""}

      assert {:error, "command is required"} = Task.new(attrs)
    end

    test "returns error when requires is not a list" do
      attrs = %{name: "task-1", command: "echo hello", requires: "not-a-list"}

      assert {:error, "requires must be a list"} = Task.new(attrs)
    end

    test "returns error when requires contains non-string values" do
      attrs = %{name: "task-1", command: "echo hello", requires: ["task-2", 123]}

      assert {:error, "requires must contain only strings"} = Task.new(attrs)
    end

    test "returns error when attrs is not a map" do
      assert {:error, "attributes must be a map"} = Task.new("not-a-map")
      assert {:error, "attributes must be a map"} = Task.new([])
    end

    test "handles empty requires list" do
      attrs = %{name: "task-1", command: "echo hello", requires: []}

      assert {:ok, %Task{requires: []}} = Task.new(attrs)
    end

    test "handles nil requires" do
      attrs = %{name: "task-1", command: "echo hello", requires: nil}

      assert {:ok, %Task{requires: []}} = Task.new(attrs)
    end
  end

  describe "validate/1" do
    test "returns ok for valid task" do
      task = %Task{name: "task-1", command: "echo hello", requires: []}

      assert :ok = Task.validate(task)
    end

    test "returns ok for task with requires" do
      task = %Task{name: "task-1", command: "echo hello", requires: ["task-2"]}

      assert :ok = Task.validate(task)
    end

    test "returns error when name is missing" do
      task = %Task{name: nil, command: "echo hello", requires: []}

      assert {:error, "name is required"} = Task.validate(task)
    end

    test "returns error when name is empty" do
      task = %Task{name: "", command: "echo hello", requires: []}

      assert {:error, "name is required"} = Task.validate(task)
    end

    test "returns error when command is missing" do
      task = %Task{name: "task-1", command: nil, requires: []}

      assert {:error, "command is required"} = Task.validate(task)
    end

    test "returns error when command is empty" do
      task = %Task{name: "task-1", command: "", requires: []}

      assert {:error, "command is required"} = Task.validate(task)
    end

    test "returns error when requires is not a list" do
      task = %Task{name: "task-1", command: "echo hello", requires: "not-a-list"}

      assert {:error, "requires must be a list"} = Task.validate(task)
    end

    test "returns error when requires contains non-string values" do
      task = %Task{name: "task-1", command: "echo hello", requires: ["task-2", 123]}

      assert {:error, "requires must contain only strings"} = Task.validate(task)
    end

    test "returns error for invalid struct" do
      assert {:error, "invalid task struct"} = Task.validate(%{name: "task-1"})
    end
  end
end
