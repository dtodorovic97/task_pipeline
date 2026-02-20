# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TaskPipeline.Repo.insert!(%TaskPipeline.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias TaskPipeline.Repo
alias TaskPipeline.Tasks.Task

now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

tasks = [
  %{
    title: "Import Queens gallery",
    type: :import,
    priority: :critical,
    payload: %{"when" => "now"},
    max_attempts: 3,
    status: :queued,
    attempts: [],
    inserted_at: now,
    updated_at: now
  },
  %{
    title: "Tie shoes",
    type: :cleanup,
    priority: :low,
    payload: %{"whose" => "mine"},
    max_attempts: 2,
    status: :failed,
    attempts: [%{attempt: 1, timestamp: now, result: "error", error: "Access denied"}],
    inserted_at: now,
    updated_at: now
  },
  %{
    title: "Liquidate old inventory",
    type: :report,
    priority: :high,
    payload: %{"demand" => "now"},
    max_attempts: 4,
    status: :processing,
    attempts: [%{attempt: 1, timestamp: now, result: "started"}],
    inserted_at: now,
    updated_at: now
  },
  %{
    title: "Open portal to another dimension",
    type: :export,
    priority: :normal,
    payload: %{"destination" => "unknown"},
    max_attempts: 2,
    status: :completed,
    attempts: [%{attempt: 1, timestamp: now, result: "success"}],
    inserted_at: now,
    updated_at: now
  }
]

Repo.insert_all(Task, tasks)
