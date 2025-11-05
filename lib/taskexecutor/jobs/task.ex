defmodule Taskexecutor.Jobs.Task do
  @moduledoc """
  Defines the Task struct and validation logic for job tasks.

  A task has a name, a shell command to execute, and an optional list of
  task names that must be executed before this task.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          command: String.t(),
          requires: list(String.t())
        }

  @type validation_error :: {:error, String.t()}

  defstruct [:name, :command, requires: []]

  @doc """
  Creates a new task from a map of attributes.

  Returns `{:ok, task}` on success or `{:error, reason}` on validation failure.

  ## Examples

      iex> new(%{name: "task-1", command: "echo hello"})
      {:ok, %Taskexecutor.Jobs.Task{name: "task-1", command: "echo hello", requires: []}}

      iex> new(%{name: "task-1", command: "echo hello", requires: ["task-2"]})
      {:ok, %Taskexecutor.Jobs.Task{name: "task-1", command: "echo hello", requires: ["task-2"]}}

      iex> new(%{name: "task-1"})
      {:error, "command is required"}
  """
  @spec new(map()) :: {:ok, t()} | validation_error()
  def new(attrs) when is_map(attrs) do
    with :ok <- validate_name(attrs),
         :ok <- validate_command(attrs),
         :ok <- validate_requires(attrs) do
      task = %__MODULE__{
        name: attrs[:name] || attrs["name"],
        command: attrs[:command] || attrs["command"],
        requires: normalize_requires(attrs[:requires] || attrs["requires"] || [])
      }

      {:ok, task}
    end
  end

  def new(_), do: {:error, "attributes must be a map"}

  @doc """
  Validates a task struct.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.
  """
  @spec validate(t()) :: :ok | validation_error()
  def validate(%__MODULE__{name: name, command: command, requires: requires}) do
    cond do
      is_nil(name) or name == "" ->
        {:error, "name is required"}

      is_nil(command) or command == "" ->
        {:error, "command is required"}

      not is_list(requires) ->
        {:error, "requires must be a list"}

      not Enum.all?(requires, &is_binary/1) ->
        {:error, "requires must contain only strings"}

      true ->
        :ok
    end
  end

  def validate(_), do: {:error, "invalid task struct"}

  defp validate_name(attrs) do
    name = attrs[:name] || attrs["name"]

    if is_binary(name) and name != "" do
      :ok
    else
      {:error, "name is required"}
    end
  end

  defp validate_command(attrs) do
    command = attrs[:command] || attrs["command"]

    if is_binary(command) and command != "" do
      :ok
    else
      {:error, "command is required"}
    end
  end

  defp validate_requires(attrs) do
    requires = attrs[:requires] || attrs["requires"] || []

    cond do
      not is_list(requires) ->
        {:error, "requires must be a list"}

      not Enum.all?(requires, &is_binary/1) ->
        {:error, "requires must contain only strings"}

      true ->
        :ok
    end
  end

  defp normalize_requires(requires) when is_list(requires), do: requires
  defp normalize_requires(_), do: []
end
