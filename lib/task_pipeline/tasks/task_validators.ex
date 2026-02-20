defmodule TaskPipeline.Tasks.TaskValidators do
  @moduledoc """
  Embedded schema for validating task parameters.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias TaskPipeline.Tasks.Task

  @primary_key false

  embedded_schema do
    field :status, :string
    field :type, :string
    field :priority, :string
  end

  @doc false
  def changeset(filters, params) do
    filters
    |> cast(params, [:status, :type, :priority])
    |> validate_inclusion(:status, enum_strings(Task.status_values()),  message: "invalid status")
    |> validate_inclusion(:type, enum_strings(Task.type_values()), message: "invalid type")
    |> validate_inclusion(:priority, enum_strings(Task.priority_values()), message: "invalid priority")

  end

  defp enum_strings(values), do: Enum.map(values, &Atom.to_string/1)

  def parse_http_params(params) do
    cs = changeset(%__MODULE__{}, params)

    if cs.valid? do
      {:ok, cs |> apply_changes() |> filter_to_atoms()}
    else
      {:error, cs}
    end
  end

  defp filter_to_atoms(%__MODULE__{} = f) do
    f
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, String.to_existing_atom(v)} end)
  end

  def validate_status_transition(changeset) do
    new_status = get_change(changeset, :status)
    old_status = changeset.data.status

    cond do
      is_nil(new_status) -> changeset
      valid_transition?(old_status, new_status) -> changeset
      true -> add_error(changeset, :status, "invalid status transition from #{old_status} to #{new_status}")
    end
  end

  defp valid_transition?(:queued, :processing), do: true
  defp valid_transition?(:processing, :completed), do: true
  defp valid_transition?(:processing, :queued), do: true
  defp valid_transition?(:processing, :failed), do: true
  defp valid_transition?(_, _), do: false
end
