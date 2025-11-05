defmodule Taskexecutor.Jobs.Formatter do
  @moduledoc """
  Provides functions for formatting sorted tasks into different output formats.
  """

  alias Taskexecutor.Jobs.Task

  @doc """
  Formats a list of tasks into a bash script.

  Returns a string with shebang and commands, one per line.

  ## Examples

      iex> tasks = [
      ...>   %Taskexecutor.Jobs.Task{name: "task-1", command: "echo hello"},
      ...>   %Taskexecutor.Jobs.Task{name: "task-2", command: "echo world"}
      ...> ]
      iex> Formatter.to_bash_script(tasks)
      "#!/usr/bin/env bash\\necho hello\\necho world\\n"
  """
  @spec to_bash_script(list(Task.t())) :: String.t()
  def to_bash_script([]) do
    "#!/usr/bin/env bash\n"
  end

  def to_bash_script(tasks) do
    commands = Enum.map_join(tasks, "\n", & &1.command)

    "#!/usr/bin/env bash\n" <> commands <> "\n"
  end
end
