defmodule TaskexecutorWeb.FallbackController do
  @moduledoc """
  Fallback controller for handling errors in a centralized way.

  This controller handles `{:error, reason}` tuples returned from
  controller actions, providing consistent error responses.
  """

  use TaskexecutorWeb, :controller

  @doc """
  Handles error tuples returned from controller actions.

  Translates error reasons into appropriate HTTP status codes
  and formatted JSON error responses.
  """
  def call(conn, {:error, reason}) do
    status = determine_error_status(reason)

    conn
    |> put_status(status)
    |> json(%{
      error: format_error_type(reason),
      message: reason
    })
  end

  defp determine_error_status(reason) do
    cond do
      reason =~ "invalid job data" -> :bad_request
      reason =~ "circular dependency" -> :unprocessable_entity
      reason =~ "is referenced but does not exist" -> :unprocessable_entity
      true -> :bad_request
    end
  end

  defp format_error_type(reason) do
    cond do
      reason =~ "circular dependency" -> "circular_dependency"
      reason =~ "is referenced but does not exist" -> "missing_task_reference"
      reason =~ "invalid job data" -> "invalid_request"
      reason =~ "tasks field is required" -> "invalid_request"
      reason =~ "must be" -> "validation_error"
      reason =~ "is required" -> "validation_error"
      true -> "invalid_request"
    end
  end
end
