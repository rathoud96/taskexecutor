defmodule Taskexecutor.Jobs.FormatterTest do
  use ExUnit.Case, async: true

  alias Taskexecutor.Jobs.{Formatter, Task}

  describe "to_bash_script/1" do
    test "formats tasks into bash script with shebang" do
      tasks = [
        %Task{name: "task-1", command: "echo hello", requires: []},
        %Task{name: "task-2", command: "echo world", requires: []}
      ]

      script = Formatter.to_bash_script(tasks)

      assert script =~ "#!/usr/bin/env bash"
      assert script =~ "echo hello"
      assert script =~ "echo world"
    end

    test "includes each command on a new line" do
      tasks = [
        %Task{name: "task-1", command: "touch /tmp/file1", requires: []},
        %Task{name: "task-2", command: "cat /tmp/file1", requires: []},
        %Task{name: "task-3", command: "rm /tmp/file1", requires: []}
      ]

      script = Formatter.to_bash_script(tasks)
      lines = String.split(script, "\n", trim: true)

      assert length(lines) == 4 # shebang + 3 commands
      assert List.first(lines) == "#!/usr/bin/env bash"
      assert Enum.at(lines, 1) == "touch /tmp/file1"
      assert Enum.at(lines, 2) == "cat /tmp/file1"
      assert Enum.at(lines, 3) == "rm /tmp/file1"
    end

    test "matches example from requirements" do
      tasks = [
        %Task{name: "task-1", command: "touch /tmp/file1", requires: []},
        %Task{name: "task-3", command: "echo 'Hello World!' > /tmp/file1", requires: ["task-1"]},
        %Task{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
        %Task{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
      ]

      script = Formatter.to_bash_script(tasks)
      lines = String.split(script, "\n", trim: true)

      assert List.first(lines) == "#!/usr/bin/env bash"
      assert Enum.at(lines, 1) == "touch /tmp/file1"
      assert Enum.at(lines, 2) == "echo 'Hello World!' > /tmp/file1"
      assert Enum.at(lines, 3) == "cat /tmp/file1"
      assert Enum.at(lines, 4) == "rm /tmp/file1"
    end

    test "handles empty task list" do
      script = Formatter.to_bash_script([])

      assert script == "#!/usr/bin/env bash\n"
    end

    test "handles commands with special characters" do
      tasks = [
        %Task{name: "task-1", command: "echo 'Hello & World'", requires: []},
        %Task{name: "task-2", command: "echo \"test\" > /tmp/file", requires: []}
      ]

      script = Formatter.to_bash_script(tasks)

      assert script =~ "echo 'Hello & World'"
      assert script =~ "echo \"test\" > /tmp/file"
    end
  end
end
