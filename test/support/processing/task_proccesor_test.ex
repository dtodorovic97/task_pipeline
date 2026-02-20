defmodule TaskPipeline.TaskProcessorTest do
  use TaskPipeline.DataCase
  use Oban.Testing, repo: TaskPipeline.Repo

  alias TaskPipeline.TasksHandler
  alias TaskPipeline.Workers.TaskProcessor
  import TaskPipeline.TasksFixtures

  describe "task execution lifecycle" do
    test "successfully processes a queued task" do
      task = task_fixture(%{priority: :critical, max_attempts: 3})
      :rand.seed(:exsplus, {1, 2, 3})

      assert :ok ==
               TaskProcessor.perform(%Oban.Job{
                 args: %{"task_id" => task.id},
                 attempt: 1
               })

      reloaded = TasksHandler.get_task!(task.id)

      assert reloaded.status == :completed
      assert length(reloaded.attempts) == 1

      [attempt] = reloaded.attempts

      assert attempt_value(attempt, "attempt") == 1
      assert attempt_value(attempt, "result") == "success"
      assert attempt_value(attempt, "timestamp") != nil
    end

    test "requeues task on failure before reaching max_attempts" do
      task = task_fixture(%{priority: :critical, max_attempts: 3})
      :rand.seed(:exsplus, {2, 3, 4})

      assert {:error, _} =
               TaskProcessor.perform(%Oban.Job{
                 args: %{"task_id" => task.id},
                 attempt: 1
               })

      reloaded = TasksHandler.get_task!(task.id)

      assert reloaded.status == :queued
      assert length(reloaded.attempts) == 1

      [attempt] = reloaded.attempts
      assert attempt_value(attempt, "result") == "error"
      assert attempt_value(attempt, "error") == "Simulated random failure"
    end

    test "marks task as failed after last retry" do
      task = raw_task_fixture(%{priority: :critical, max_attempts: 2})
      :rand.seed(:exsplus, {2, 3, 4})

      assert {:error, _} =
               TaskProcessor.perform(%Oban.Job{
                 args: %{"task_id" => task.id},
                 attempt: 2
               })

      reloaded = TasksHandler.get_task!(task.id)

      assert reloaded.status == :failed
      assert length(reloaded.attempts) == 1
    end

    test "does nothing if task is already being processed" do
      task = task_fixture()
      assert {:ok, _} = TasksHandler.claim_task(task.id)

      assert :ok ==
               TaskProcessor.perform(%Oban.Job{
                 args: %{"task_id" => task.id},
                 attempt: 1
               })

      unchanged = TasksHandler.get_task!(task.id)

      assert unchanged.status == :processing
      assert unchanged.attempts == []
    end
  end

  defp attempt_value(map, key) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
  end
end
