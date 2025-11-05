defmodule TaskexecutorWeb.JobControllerTest do
  use TaskexecutorWeb.ConnCase, async: true

  describe "POST /api/jobs/process" do
    test "processes a valid job and returns sorted tasks", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "touch /tmp/file1"},
          %{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
          %{name: "task-3", command: "echo 'Hello World!' > /tmp/file1", requires: ["task-1"]},
          %{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 200) =~ "tasks"
      assert json_response(conn, 200)["tasks"] |> length() == 4

      tasks = json_response(conn, 200)["tasks"]
      sorted_names = Enum.map(tasks, & &1["name"])

      # Verify correct order
      assert Enum.at(sorted_names, 0) == "task-1"
      assert Enum.at(sorted_names, 1) == "task-3"
      assert Enum.at(sorted_names, 2) == "task-2"
      assert Enum.at(sorted_names, 3) == "task-4"

      # Verify task structure (no requires field in response)
      first_task = List.first(tasks)
      assert Map.has_key?(first_task, "name")
      assert Map.has_key?(first_task, "command")
      refute Map.has_key?(first_task, "requires")
    end

    test "returns sorted tasks in correct order for simple dependencies", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1"},
          %{name: "task-2", command: "echo 2", requires: ["task-1"]},
          %{name: "task-3", command: "echo 3", requires: ["task-2"]}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 200)

      tasks = json_response(conn, 200)["tasks"]
      sorted_names = Enum.map(tasks, & &1["name"])

      assert sorted_names == ["task-1", "task-2", "task-3"]
    end

    test "returns 400 for invalid JSON structure", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(%{invalid: "data"}))

      assert response(conn, 400)
      assert json_response(conn, 400)["error"]
      assert json_response(conn, 400)["message"]
    end

    test "returns 400 when tasks field is missing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(%{}))

      assert response(conn, 400)
      assert json_response(conn, 400)["error"] == "invalid_request"
      assert json_response(conn, 400)["message"] =~ "tasks field is required"
    end

    test "returns 400 when tasks is not a list", %{conn: conn} do
      conn = post(conn, ~p"/api/jobs/process", %{tasks: "not-a-list"})

      assert response(conn, 400)
      assert json_response(conn, 400)["error"] == "validation_error"
    end

    test "returns 400 when task name is missing", %{conn: conn} do
      job_data = %{
        tasks: [
          %{command: "echo hello"}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 400)
      assert json_response(conn, 400)["error"] == "validation_error"
      assert json_response(conn, 400)["message"] =~ "name is required"
    end

    test "returns 400 when task command is missing", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1"}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 400)
      assert json_response(conn, 400)["error"] == "validation_error"
      assert json_response(conn, 400)["message"] =~ "command is required"
    end

    test "returns 422 when task reference does not exist", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1", requires: ["missing-task"]}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 422)
      assert json_response(conn, 422)["error"] == "missing_task_reference"
      assert json_response(conn, 422)["message"] =~ "is referenced but does not exist"
    end

    test "returns 422 when circular dependency detected", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1", requires: ["task-2"]},
          %{name: "task-2", command: "echo 2", requires: ["task-1"]}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 422)
      assert json_response(conn, 422)["error"] == "circular_dependency"
      assert json_response(conn, 422)["message"] =~ "circular dependency"
    end

    test "returns 422 for self-referential dependency", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1", requires: ["task-1"]}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 422)
      assert json_response(conn, 422)["error"] == "circular_dependency"
      assert json_response(conn, 422)["message"] =~ "circular dependency"
    end

    test "handles tasks with no dependencies", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1"},
          %{name: "task-2", command: "echo 2"},
          %{name: "task-3", command: "echo 3"}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 200)
      tasks = json_response(conn, 200)["tasks"]
      assert length(tasks) == 3

      # All tasks should be present (order may vary for tasks with no deps)
      task_names = Enum.map(tasks, & &1["name"])
      assert "task-1" in task_names
      assert "task-2" in task_names
      assert "task-3" in task_names
    end

    test "handles empty requires array", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1", requires: []},
          %{name: "task-2", command: "echo 2", requires: ["task-1"]}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 200)
      tasks = json_response(conn, 200)["tasks"]
      assert length(tasks) == 2
      assert Enum.at(tasks, 0)["name"] == "task-1"
      assert Enum.at(tasks, 1)["name"] == "task-2"
    end

    test "handles complex dependency graph", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo 1"},
          %{name: "task-2", command: "echo 2", requires: ["task-1"]},
          %{name: "task-3", command: "echo 3", requires: ["task-1"]},
          %{name: "task-4", command: "echo 4", requires: ["task-2", "task-3"]}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 200)
      tasks = json_response(conn, 200)["tasks"]
      assert length(tasks) == 4

      sorted_names = Enum.map(tasks, & &1["name"])

      # task-1 must come first
      assert Enum.at(sorted_names, 0) == "task-1"

      # task-4 must come last
      assert Enum.at(sorted_names, 3) == "task-4"

      # task-2 and task-3 must come between task-1 and task-4
      middle = Enum.slice(sorted_names, 1, 2)
      assert "task-2" in middle
      assert "task-3" in middle
    end
  end

  describe "response format selection" do
    test "returns JSON by default", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo hello"},
          %{name: "task-2", command: "echo world"}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"
      assert json_response(conn, 200)["tasks"]
    end

    test "returns bash script when format=bash query parameter is provided", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo hello"},
          %{name: "task-2", command: "echo world"}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process?format=bash", Jason.encode!(job_data))

      assert response(conn, 200)
      content_type = get_resp_header(conn, "content-type") |> List.first()
      assert content_type =~ "text/x-shellscript"

      script = response(conn, 200)
      assert script =~ "#!/usr/bin/env bash"
      assert script =~ "echo hello"
      assert script =~ "echo world"
    end

    test "returns bash script when Accept header is text/x-shellscript", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo hello"},
          %{name: "task-2", command: "echo world"}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("accept", "application/json, text/x-shellscript")
        |> post(~p"/api/jobs/process", Jason.encode!(job_data))

      assert response(conn, 200)
      content_type = get_resp_header(conn, "content-type") |> List.first()
      assert content_type =~ "text/x-shellscript"

      script = response(conn, 200)
      assert script =~ "#!/usr/bin/env bash"
    end

    test "returns JSON when format=json query parameter is provided", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo hello"}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process?format=json", Jason.encode!(job_data))

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"
      assert json_response(conn, 200)["tasks"]
    end

    test "bash script format matches example from requirements", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "touch /tmp/file1"},
          %{name: "task-2", command: "cat /tmp/file1", requires: ["task-3"]},
          %{name: "task-3", command: "echo 'Hello World!' > /tmp/file1", requires: ["task-1"]},
          %{name: "task-4", command: "rm /tmp/file1", requires: ["task-2", "task-3"]}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process?format=bash", Jason.encode!(job_data))

      assert response(conn, 200)

      script = response(conn, 200)
      lines = String.split(script, "\n")

      # Check shebang
      assert List.first(lines) == "#!/usr/bin/env bash"

      # Check commands are in correct order
      assert Enum.at(lines, 1) == "touch /tmp/file1"
      assert Enum.at(lines, 2) == "echo 'Hello World!' > /tmp/file1"
      assert Enum.at(lines, 3) == "cat /tmp/file1"
      assert Enum.at(lines, 4) == "rm /tmp/file1"
    end

    test "bash script has one command per line", %{conn: conn} do
      job_data = %{
        tasks: [
          %{name: "task-1", command: "echo hello"},
          %{name: "task-2", command: "echo world"}
        ]
      }

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/api/jobs/process?format=bash", Jason.encode!(job_data))

      script = response(conn, 200)
      lines = String.split(script, "\n", trim: true)

      # Should have shebang + 2 commands = 3 lines
      assert length(lines) == 3
      assert List.first(lines) == "#!/usr/bin/env bash"
      assert "echo hello" in lines
      assert "echo world" in lines
    end
  end
end
