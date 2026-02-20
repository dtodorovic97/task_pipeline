defmodule TaskPipeline.TasksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `TaskPipeline.Tasks` context.
  """
  alias TaskPipeline.Repo
  alias TaskPipeline.Tasks.Task
  alias TaskPipeline.TasksHandler

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{
        attempts: [],
        max_attempts: 5,
        payload: %{},
        priority: :normal,
        status: :queued,
        title: "some title",
        type: :import
      })
      |> TasksHandler.create_task()

    task
  end

  def raw_task_fixture(attrs \\ %{}) do
    data =
      Map.merge(
        %{
          title: "raw title",
          type: :import,
          priority: :normal,
          attempts: [],
          payload: %{},
          max_attempts: 5,
          status: :queued
        },
        Map.new(attrs)
      )

    %Task{}
    |> Map.merge(data)
    |> Repo.insert!()
  end
end
