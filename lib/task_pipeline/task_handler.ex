defmodule TaskPipeline.TasksHandler do
  @moduledoc """
  The Tasks context.
  """

  import Ecto.Query, warn: false
  alias TaskPipeline.Repo
  alias TaskPipeline.Tasks.Task
  alias TaskPipeline.Tasks.TaskValidators
  alias TaskPipeline.Workers.TaskProcessor

  @doc """
  Returns the list of tasks with optional filtering and sorting.

  Returns:
    * `{:ok, tasks}` when filters are valid
    * `{:error, changeset}` when filters are invalid

  Tasks are sorted by priority (critical, high, normal, low)
  and then by creation time (newest first).

  ## Filters (all optional):
    * `status`
    * `type`
    * `priority`

  ## Examples
      iex> list_tasks(%{})
      {:ok, [%Task{}, ...]}

      iex> list_tasks(%{"status" => "queued"})
      {:ok, [%Task{status: :queued}, ...]}

      iex> list_tasks(%{"type" => "import", "priority" => "high"})
      {:ok, [%Task{type: :import, priority: :high}, ...]}

      iex> list_tasks(%{"status" => "invalid"})
      {:error, %Ecto.Changeset{}}
  """

  def list_tasks(params) do
    with {:ok, filters} <- TaskValidators.parse_http_params(params) do
      tasks =
        Task
        |> apply_filters(filters)
        |> order_by([t], desc: t.priority, desc: t.inserted_at)
        |> Repo.all()

      {:ok, tasks}
    end
  end

  @doc """
  Gets a single task.

  Raises `Ecto.NoResultsError` if the Task does not exist.

  ## Examples

      iex> get_task!(123)
      %Task{}

      iex> get_task!(456)
      ** (Ecto.NoResultsError)

  """
  def get_task!(id), do: Repo.get!(Task, id)

  @doc """
  Gets a single task by id.

  Returns:
    * `{:ok, task}` when the task exists
    * `{:error, :not_found}` when the task does not exist

  ## Examples

      iex> get_task(123)
      {:ok, %Task{}}

      iex> get_task(456)
      {:error, :not_found}
  """
  def get_task(id) do
    case Repo.get(Task, id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  @doc """
  Creates a task and schedules it for async processing.

  Returns:
    * `{:ok, task}` when the task is inserted and the job is enqueued
    * `{:error, changeset}` when task validation or insert fails
    * `{:error, reason}` when job enqueue fails and the transaction is rolled back

  ## Examples

      iex> create_task(%{field: value})
      {:ok, %Task{}}

      iex> create_task(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_task(attrs) do
    Repo.transact(fn ->
      changeset = change_task(%Task{}, attrs)

      with {:ok, task} <- Repo.insert(changeset), {:ok, _job} <- TaskProcessor.schedule(task) do
        {:ok, task}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Updates a task.

  ## Examples

      iex> update_task(task, %{field: new_value})
      {:ok, %Task{}}

      iex> update_task(task, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking task changes.

  ## Examples

      iex> change_task(task)
      %Ecto.Changeset{data: %Task{}}

  """
  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  @doc """
  Returns aggregate counts of tasks grouped by status.

  Always returns all four statuses with a count, even if zero.

  ## Examples

      iex> get_summary()
      %{queued: 5, processing: 2, completed: 12, failed: 1}

      iex> get_summary()
      %{queued: 0, processing: 0, completed: 0, failed: 0}

  """
  def get_summary do
    counts =
      Task
      |> group_by([t], t.status)
      |> select([t], {t.status, count(t.id)})
      |> Repo.all()
      |> Map.new()

    Task.status_values()
    |> Enum.map(&{&1, 0})
    |> Map.new()
    |> Map.merge(counts)
  end

  @doc """
  Atomically claims a task for processing.

  Returns:
    * `{:ok, task}` - Successfully claimed the task
    * `{:error, :not_claimed}` - Task doesn't exist or already claimed

  ## Examples

      iex> claim_task_for_processing(123)
      {:ok, %Task{status: :processing}}

      iex> claim_task_for_processing(123)
      {:error, :not_claimed}
  """
  def claim_task(task_id) do
    from(t in Task, where: t.id == ^task_id and t.status == :queued, select: t)
    |> Repo.update_all(set: [status: :processing, updated_at: NaiveDateTime.utc_now()])
    |> case do
      {1, [task]} -> {:ok, task}
      _ -> {:error, :not_claimed}
    end
  end

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, value}, query when value != nil -> where(query, [t], t.status == ^value)
      {:type, value}, query when value != nil -> where(query, [t], t.type == ^value)
      {:priority, value}, query when value != nil -> where(query, [t], t.priority == ^value)
      _, query -> query
    end)
  end
end
