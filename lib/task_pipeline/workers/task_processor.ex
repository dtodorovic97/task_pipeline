defmodule TaskPipeline.Workers.TaskProcessor do
  @moduledoc """
  Oban worker for processing tasks asynchronously.
  """

  use Oban.Worker
  alias TaskPipeline.TasksHandler
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task_id" => task_id}, attempt: attempt}) do
    TasksHandler.claim_task(task_id)
    |> case do
      {:ok, task} ->
        result = simulate_task(task)
        handle_attempt(result, task, attempt)

      _ ->
        :ok
    end
  end

  @doc """
  Schedules an Oban job for the given task.

  Creates a new Oban job with the task's max_attempts configuration.
  The job will be enqueued immediately and processed by the next available worker.

  ## Examples

      iex> task = %Task{id: 1, max_attempts: 5}
      iex> TaskProcessor.schedule(task)
      {:ok, %Oban.Job{}}
  """
  def schedule(task) do
    %{task_id: task.id}
    |> new(max_attempts: task.max_attempts)
    |> Oban.insert()
  end

  defp simulate_task(task) do
    task
    |> calculate_sleep_duration()
    |> Process.sleep()

    if :rand.uniform(100) <= 20 do
      {:error, "Simulated random failure"}
    else
      :ok
    end
  end

  defp handle_attempt(result, task, attempt) do
    attempt_data = extract_attempt_data(result, attempt)
    new_attempts = task.attempts ++ [attempt_data]
    new_status = determine_new_status(result, attempt, task.max_attempts)

    case TasksHandler.update_task(task, %{status: new_status, attempts: new_attempts}) do
      {:ok, _task} ->
        case new_status do
          :completed -> :ok
          :failed -> {:error, "Max attempts exhausted"}
          _ -> result
        end

      _ ->
        {:error, "Failed to update task"}
    end
  end

  defp determine_new_status(:ok, _attempt, _max_attempts), do: :completed

  defp determine_new_status({:error, _}, attempt, max_attempts) do
    if attempt >= max_attempts do
      :failed
    else
      :queued
    end
  end

  defp extract_attempt_data(:ok, attempt) do
    %{
      attempt: attempt,
      timestamp: NaiveDateTime.utc_now(),
      result: "success"
    }
  end

  defp extract_attempt_data({:error, error_message}, attempt) do
    %{
      attempt: attempt,
      timestamp: NaiveDateTime.utc_now(),
      result: "error",
      error: error_message
    }
  end

  defp calculate_sleep_duration(%{priority: priority}) do
    case priority do
      :critical -> Enum.random(1000..2000)
      :high -> Enum.random(2000..4000)
      :normal -> Enum.random(4000..6000)
      :low -> Enum.random(6000..8000)
    end
  end
end
