defmodule TaskPipelineWeb.TaskController do
  use TaskPipelineWeb, :controller

  alias TaskPipeline.TasksHandler
  alias TaskPipeline.Tasks.Task

  action_fallback TaskPipelineWeb.FallbackController

  def index(conn, params) do
    with {:ok, tasks} <- TasksHandler.list_tasks(params) do
      render(conn, :index, tasks: tasks)
    end
  end

  def show(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {int_id, ""} ->
        with {:ok, task} <- TasksHandler.get_task(int_id) do
          render(conn, :show, task: task)
        end

      _ ->
        {:error, "id: #{inspect(id)} is not valid"}
    end
  end

  def create(conn, %{"task" => task_params}) do
    with {:ok, %Task{} = task} <- TasksHandler.create_task(task_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/tasks/#{task}")
      |> render(:show, task: task)
    end
  end

  def summary(conn, _params) do
    summary = TasksHandler.get_summary()
    render(conn, :summary, summary: summary)
  end
end
