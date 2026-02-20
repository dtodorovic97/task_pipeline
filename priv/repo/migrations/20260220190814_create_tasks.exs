defmodule TaskPipeline.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def up do
    execute("""
      CREATE TYPE task_type AS ENUM (
        'import',
        'export',
        'report',
        'cleanup'
      )
    """)

    execute("""
      CREATE TYPE task_priority AS ENUM (
        'low',
        'normal',
        'high',
        'critical'
      )
    """)

    execute("""
       CREATE TYPE task_status AS ENUM (
        'queued',
        'processing',
        'completed',
        'failed'
      )
    """)

    create table(:tasks) do
      add :title, :text, null: false
      add :type, :task_type, null: false
      add :priority, :task_priority, null: false
      add :payload, :jsonb, null: false
      add :max_attempts, :integer, null: false, default: 3
      add :status, :task_status, null: false, default: "queued"
      add :attempts, :jsonb, null: false, default: fragment("'[]'::jsonb")

      timestamps(type: :naive_datetime)
    end

    create constraint(
             :tasks,
             :max_attempts_must_be_positive,
             check: "max_attempts >= 1"
           )

    create index(:tasks, [:status, :priority, :inserted_at])
    create index(:tasks, [:type])
  end

  def down do
    drop(table(:tasks))

    execute("DROP TYPE task_status")
    execute("DROP TYPE task_priority")
    execute("DROP TYPE task_type")
  end
end
