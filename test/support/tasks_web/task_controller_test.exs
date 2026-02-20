defmodule TaskPipelineWeb.TaskControllerTest do
  use TaskPipelineWeb.ConnCase
  use Oban.Testing, repo: TaskPipeline.Repo

  import TaskPipeline.TasksFixtures

  @valid_payload %{
    title: "cleanup temp files",
    type: :cleanup,
    priority: :low,
    payload: %{"path" => "/tmp/reports"},
    max_attempts: 4
  }

  @invalid_payload %{
    title: nil,
    type: nil,
    payload: nil,
    max_attempts: 0
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "listing tasks" do
    test "orders by priority (desc) and then newest first", %{conn: conn} do
      raw_task_fixture(%{priority: :low, title: "low"})
      raw_task_fixture(%{priority: :critical, title: "critical"})
      raw_task_fixture(%{priority: :high, title: "high"})

      conn = get(conn, ~p"/api/tasks")
      titles = json_response(conn, 200)["data"] |> Enum.map(& &1["title"])

      assert hd(titles) == "critical"
      assert Enum.member?(titles, "low")
    end

    test "applies multiple filters simultaneously", %{conn: conn} do
      expected =
        raw_task_fixture(%{
          status: :queued,
          type: :import,
          priority: :high,
          title: "expected"
        })

      raw_task_fixture(%{status: :queued, type: :export, priority: :high})
      raw_task_fixture(%{status: :completed, type: :import, priority: :high})

      conn =
        get(conn, ~p"/api/tasks?status=queued&type=import&priority=high")

      [%{"id" => id}] = json_response(conn, 200)["data"]
      assert id == expected.id
    end

    test "responds with 422 for invalid query params", %{conn: conn} do
      conn = get(conn, ~p"/api/tasks?status=unknown")

      assert %{"errors" => errors} = json_response(conn, 422)
      assert Map.has_key?(errors, "status")
    end
  end

  describe "creating tasks" do
    test "persists task and returns 201 with location header", %{conn: conn} do
      conn = post(conn, ~p"/api/tasks", task: @valid_payload)

      %{"data" => data} = json_response(conn, 201)

      assert data["status"] == "queued"
      assert data["attempts"] == []
      assert data["max_attempts"] == 4
      assert get_resp_header(conn, "location") == ["/api/tasks/#{data["id"]}"]
    end

    test "enqueues background job with correct args", %{conn: conn} do
      conn = post(conn, ~p"/api/tasks", task: @valid_payload)
      id = json_response(conn, 201)["data"]["id"]

      assert_enqueued(
        worker: TaskPipeline.Workers.TaskProcessor,
        args: %{"task_id" => id},
        max_attempts: 4
      )
    end

    test "ignores client-supplied status and attempts", %{conn: conn} do
      tampered =
        Map.merge(@valid_payload, %{
          status: :failed,
          attempts: [%{attempt: 1, result: "error"}]
        })

      conn = post(conn, ~p"/api/tasks", task: tampered)
      data = json_response(conn, 201)["data"]

      assert data["status"] == "queued"
      assert data["attempts"] == []
    end

    test "returns validation errors for malformed input", %{conn: conn} do
      conn = post(conn, ~p"/api/tasks", task: @invalid_payload)

      %{"errors" => errors} = json_response(conn, 422)

      assert Map.has_key?(errors, "title")
      assert Map.has_key?(errors, "type")
      assert Map.has_key?(errors, "payload")
      assert Map.has_key?(errors, "max_attempts")
    end
  end

  describe "showing a task" do
    test "returns full task representation including attempts", %{conn: conn} do
      task =
        raw_task_fixture(%{
          title: "report",
          type: :report,
          priority: :critical,
          status: :processing,
          attempts: [%{attempt: 1, result: "error", error: "timeout"}]
        })

      conn = get(conn, ~p"/api/tasks/#{task.id}")
      data = json_response(conn, 200)["data"]

      assert data["id"] == task.id
      assert data["status"] == "processing"
      assert length(data["attempts"]) == 1
    end

    test "returns 404 for missing task", %{conn: conn} do
      conn = get(conn, ~p"/api/tasks/-999")
      assert json_response(conn, 404)["errors"]
    end

    test "returns 400 for invalid id format", %{conn: conn} do
      conn = get(conn, ~p"/api/tasks/not_a_number")

      assert %{"errors" => %{"detail" => _}} =
               json_response(conn, 400)
    end
  end

  describe "task summary" do
    test "returns zero counts when empty", %{conn: conn} do
      conn = get(conn, ~p"/api/tasks/summary")

      assert %{
               "queued" => 0,
               "processing" => 0,
               "completed" => 0,
               "failed" => 0
             } = json_response(conn, 200)["data"]
    end

    test "aggregates counts correctly", %{conn: conn} do
      raw_task_fixture(%{status: :queued})
      raw_task_fixture(%{status: :processing})
      raw_task_fixture(%{status: :completed})
      raw_task_fixture(%{status: :failed})
      raw_task_fixture(%{status: :queued})

      conn = get(conn, ~p"/api/tasks/summary")
      summary = json_response(conn, 200)["data"]

      assert summary["queued"] == 2
      assert summary["failed"] == 1
    end
  end
end
