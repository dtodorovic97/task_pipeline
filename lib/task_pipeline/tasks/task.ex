defmodule TaskPipeline.Tasks.Task do
  use Ecto.Schema
  import Ecto.Changeset
  alias TaskPipeline.Tasks.TaskValidators

  @type_values [:import, :export, :report, :cleanup]
  @priority_values [:low, :normal, :high, :critical]
  @status_values [:queued, :processing, :completed, :failed]


  schema "tasks" do
    field :title, :string
    field :type, Ecto.Enum, values: @type_values
    field :priority, Ecto.Enum, values: @priority_values, default: :normal
    field :status, Ecto.Enum, values: @status_values, default: :queued
    field :payload, :map
    field :max_attempts, :integer, default: 3
    field :attempts, {:array, :map}, default: []

    timestamps(type: :naive_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :type, :priority, :payload, :max_attempts])
    |> validate_required([:title, :type, :payload])
    |> validate_number(:max_attempts, greater_than_or_equal_to: 1)
    |> validate_length(:title, min: 1)
    |> check_constraint(:max_attempts, name: :max_attempts_must_be_positive )
  end

   def update_changeset(task, attrs) do
    task
    |> cast(attrs, [:status, :attempts])
    |> validate_required([:status])
    |> TaskValidators.validate_status_transition()
  end


  def status_values, do: @status_values
  def type_values, do: @type_values
  def priority_values, do: @priority_values
end
