defmodule TaskexecutorWeb.JobController do
  @moduledoc """
  Controller for handling job processing requests.
  """

  use TaskexecutorWeb, :controller

  action_fallback TaskexecutorWeb.FallbackController

  alias Taskexecutor.{Jobs, Jobs.Formatter}

  @doc """
  Processes a job and returns sorted tasks.

  Accepts POST requests with JSON body containing job definition.
  Returns sorted tasks in JSON format (default) or bash script format.

  Format can be specified via:
  - Query parameter: `?format=bash` or `?format=json`
  - Accept header: `Accept: text/x-shellscript` or `Accept: application/json`
  """
  def process(conn, params) do
    format = determine_format(conn, params)
    job_data = normalize_keys(params)

    case Jobs.process(job_data) do
      {:ok, sorted_tasks} ->
        render_success(conn, sorted_tasks, format)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_keys(%{"tasks" => tasks}), do: %{tasks: tasks}
  defp normalize_keys(%{tasks: _} = data), do: data
  defp normalize_keys(data), do: data

  defp render_success(conn, sorted_tasks, format) do
    case format do
      :bash -> render_bash_script(conn, sorted_tasks)
      :json -> render_json(conn, sorted_tasks)
    end
  end

  defp render_json(conn, sorted_tasks) do
    json_data =
      sorted_tasks
      |> Enum.map(fn task ->
        %{
          name: task.name,
          command: task.command
        }
      end)

    conn
    |> put_status(:ok)
    |> json(%{tasks: json_data})
  end

  defp render_bash_script(conn, sorted_tasks) do
    script = Formatter.to_bash_script(sorted_tasks)

    conn
    |> put_status(:ok)
    |> put_resp_content_type("text/x-shellscript")
    |> send_resp(200, script)
  end

  defp determine_format(conn, params) do
    cond do
      # Check query parameter first
      params["format"] == "bash" || params[:format] == "bash" -> :bash
      params["format"] == "json" || params[:format] == "json" -> :json
      # Check Accept header (case-insensitive)
      get_req_header(conn, "accept")
      |> Enum.any?(fn accept ->
        accept
        |> String.downcase()
        |> String.contains?("text/x-shellscript")
      end) -> :bash
      true -> :json
    end
  end
end
