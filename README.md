# Taskexecutor

An HTTP job processing service built with Elixir and Phoenix. This service accepts job definitions (collections of tasks with dependencies) and returns them in a topologically sorted execution order.

## Features

- **Task Dependency Management**: Define tasks with dependencies on other tasks
- **Topological Sorting**: Automatically sorts tasks based on their dependencies
- **Dual Response Formats**:
  - JSON format (default)
  - Bash script format
- **Validation**: Comprehensive validation of task definitions
- **Error Handling**: Clear error messages for invalid inputs, circular dependencies, and missing references

## Requirements

- Elixir 1.18.4
- Erlang 27.3.4.2
- Phoenix ~> 1.7

## Installation

1. Install dependencies:

   ```bash
   mix setup
   ```

2. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

The server will be available at `http://localhost:4000`.

## API Usage

### Endpoint

**POST** `/api/jobs/process`

### Request Format

The request body should be a JSON object with a `tasks` array. Each task has:

- `name` (required): String - unique task identifier
- `command` (required): String - shell command to execute
- `requires` (optional): Array of strings - task names that must execute before this task

### Response Formats

#### JSON Format (Default)

Returns sorted tasks in JSON format.

**Request:**

```bash
curl -X POST http://localhost:4000/api/jobs/process \
  -H "Content-Type: application/json" \
  -d '{
    "tasks": [
      {"name": "task-1", "command": "touch /tmp/file1"},
      {"name": "task-2", "command": "cat /tmp/file1", "requires": ["task-3"]},
      {"name": "task-3", "command": "echo '\''Hello World!'\'' > /tmp/file1", "requires": ["task-1"]},
      {"name": "task-4", "command": "rm /tmp/file1", "requires": ["task-2", "task-3"]}
    ]
  }'
```

**Response:**

```json
{
  "tasks": [
    { "name": "task-1", "command": "touch /tmp/file1" },
    { "name": "task-3", "command": "echo 'Hello World!' > /tmp/file1" },
    { "name": "task-2", "command": "cat /tmp/file1" },
    { "name": "task-4", "command": "rm /tmp/file1" }
  ]
}
```

#### Bash Script Format

Returns sorted tasks as a bash script. Can be triggered via:

- Query parameter: `?format=bash`
- Accept header: `Accept: text/x-shellscript` or `Accept: application/json, text/x-shellscript`

**Request (via query parameter):**

```bash
curl -X POST "http://localhost:4000/api/jobs/process?format=bash" \
  -H "Content-Type: application/json" \
  -d '{
    "tasks": [
      {"name": "task-1", "command": "touch /tmp/file1"},
      {"name": "task-2", "command": "cat /tmp/file1", "requires": ["task-3"]},
      {"name": "task-3", "command": "echo '\''Hello World!'\'' > /tmp/file1", "requires": ["task-1"]},
      {"name": "task-4", "command": "rm /tmp/file1", "requires": ["task-2", "task-3"]}
    ]
  }'
```

**Request (via Accept header):**

```bash
curl -X POST http://localhost:4000/api/jobs/process \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/x-shellscript" \
  -d '{
    "tasks": [
      {"name": "task-1", "command": "touch /tmp/file1"},
      {"name": "task-2", "command": "cat /tmp/file1", "requires": ["task-3"]},
      {"name": "task-3", "command": "echo '\''Hello World!'\'' > /tmp/file1", "requires": ["task-1"]},
      {"name": "task-4", "command": "rm /tmp/file1", "requires": ["task-2", "task-3"]}
    ]
  }'
```

**Response:**

```bash
#!/usr/bin/env bash
touch /tmp/file1
echo 'Hello World!' > /tmp/file1
cat /tmp/file1
rm /tmp/file1
```

## Error Handling

The service returns appropriate HTTP status codes and error messages:

### 400 Bad Request

Returned for invalid request structure or validation errors:

```json
{
  "error": "validation_error",
  "message": "name is required and must be a non-empty string"
}
```

**Common causes:**

- Missing `tasks` field
- Missing required fields (`name` or `command`)
- Invalid field types

### 422 Unprocessable Entity

Returned for semantic errors:

**Circular Dependency:**

```json
{
  "error": "circular_dependency",
  "message": "circular dependency detected: task-1 -> task-2 -> task-1"
}
```

**Missing Task Reference:**

```json
{
  "error": "missing_task_reference",
  "message": "task 'missing-task' is referenced but does not exist"
}
```

## Testing

### Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/taskexecutor/jobs/task_test.exs
```

### Test Coverage

Current test coverage: **95.9%** (above the 80% requirement)

### Code Quality

Run Credo to check code quality:

```bash
mix credo --strict
```

## Project Structure

```
lib/
├── taskexecutor/
│   ├── jobs/
│   │   ├── task.ex          # Task struct and validation
│   │   ├── job.ex           # Job struct and validation
│   │   ├── sorter.ex        # Topological sort algorithm
│   │   ├── formatter.ex     # Response formatting
│   │   └── jobs.ex          # Context module
│   └── application.ex
└── taskexecutor_web/
    ├── controllers/
    │   ├── job_controller.ex        # Main controller
    │   └── fallback_controller.ex   # Error handling
    └── router.ex
test/
├── taskexecutor/jobs/        # Unit tests
├── taskexecutor_web/         # Controller tests
└── integration/              # End-to-end tests
```

## Implementation Details

### Topological Sort

The service uses a recursive DFS (Depth-First Search) approach for topological sorting:

- Builds a dependency graph from task requirements
- Detects circular dependencies using DFS with recursion stack tracking
- Sorts tasks ensuring all dependencies are satisfied before dependent tasks

### Validation

- Task-level validation: name and command are required
- Job-level validation: all referenced tasks must exist
- Type validation: ensures correct data types for all fields

## Development

### Setup

```bash
# Install dependencies
mix deps.get

# Setup assets
mix assets.setup

# Run tests
mix test
```

### Code Quality Tools

- **Credo**: Static code analysis (`mix credo`)
- **ExCoveralls**: Test coverage (`mix test --cover`)
