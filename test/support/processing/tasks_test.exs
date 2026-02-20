defmodule TaskPipeline.TasksTest do
  use TaskPipeline.DataCase
  use Oban.Testing, repo: TaskPipeline.Repo

  alias TaskPipeline.TasksHandler
  alias TaskPipeline.Tasks.Task
  import TaskPipeline.TasksFixtures

  describe "task creation" do
    test "persists a valid task and enqueues background job" do
      attrs = %{
        title: "process data",
        type: :import,
        priority: :high,
        payload: %{"source" => "file.csv"},
        max_attempts: 4
      }

      assert {:ok, %Task{} = task} = TasksHandler.create_task(attrs)

      assert task.status == :queued
      assert task.attempts == []
      assert task.max_attempts == 4

      assert_enqueued(
        worker: TaskPipeline.Workers.TaskProcessor,
        args: %{"task_id" => task.id},
        max_attempts: 4
      )
    end

    test "rejects invalid input" do
      {:error, changeset} =
        TasksHandler.create_task(%{
          title: nil,
          type: nil,
          payload: nil,
          max_attempts: 0
        })

      refute changeset.valid?
      assert errors_on(changeset)[:title]
      assert errors_on(changeset)[:type]
      assert errors_on(changeset)[:payload]
      assert errors_on(changeset)[:max_attempts]
    end
  end

  describe "retrieval" do
    test "fetches existing task" do
      task = task_fixture()
      assert {:ok, found} = TasksHandler.get_task(task.id)
      assert found.id == task.id
    end

    test "returns error for missing task" do
      assert {:error, :not_found} = TasksHandler.get_task(-999)
    end

    test "bang version raises on missing task" do
      assert_raise Ecto.NoResultsError, fn ->
        TasksHandler.get_task!(-999)
      end
    end
  end

  describe "updates and transitions" do
    test "allows valid processing transitions" do
      task = raw_task_fixture(%{status: :processing})

      assert {:ok, updated} =
               TasksHandler.update_task(task, %{status: :completed, attempts: []})

      assert updated.status == :completed
    end

    test "prevents illegal transition" do
      task = task_fixture()

      {:error, changeset} =
        TasksHandler.update_task(task, %{status: :completed})

      assert errors_on(changeset)[:status]
    end
  end

  describe "listing and filtering" do
    test "orders by priority then newest first" do
      raw_task_fixture(%{priority: :low, title: "low"})
      raw_task_fixture(%{priority: :critical, title: "critical"})

      assert {:ok, tasks} = TasksHandler.list_tasks(%{})

      assert hd(tasks).priority == :critical
    end

    test "filters by multiple params" do
      match = raw_task_fixture(%{status: :queued, type: :import, priority: :high})
      raw_task_fixture(%{status: :queued, type: :export, priority: :high})

      assert {:ok, [result]} =
               TasksHandler.list_tasks(%{
                 "status" => "queued",
                 "type" => "import",
                 "priority" => "high"
               })

      assert result.id == match.id
    end

    test "invalid filters return changeset error" do
      assert {:error, cs} = TasksHandler.list_tasks(%{"status" => "wrong"})
      refute cs.valid?
    end
  end

  describe "summary aggregation" do
    test "returns zeroed counts when empty" do
      summary = TasksHandler.get_summary()

      assert summary == %{
               queued: 0,
               processing: 0,
               completed: 0,
               failed: 0
             }
    end

    test "aggregates correctly" do
      raw_task_fixture(%{status: :queued})
      raw_task_fixture(%{status: :completed})

      summary = TasksHandler.get_summary()

      assert summary.queued == 1
      assert summary.completed == 1
    end
  end

  describe "atomic claiming" do
    test "transitions queued -> processing" do
      task = raw_task_fixture(%{status: :queued})

      assert {:ok, claimed} = TasksHandler.claim_task(task.id)
      assert claimed.status == :processing
    end

    test "returns error when not claimable" do
      task = raw_task_fixture(%{status: :processing})
      assert {:error, :not_claimed} = TasksHandler.claim_task(task.id)
    end
  end
end
