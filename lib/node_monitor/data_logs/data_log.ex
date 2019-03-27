defmodule NodeMonitor.DataLogs.DataLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "data_logs" do
    # grouping
    field :node_id,             :string
    field :timestamp,           :naive_datetime

    # stats
    field :data_unique_sensors, :integer,         default: nil
    field :data_total,          :integer,         default: nil
    field :data_valid_total,    :float,           default: nil
    field :data_valid_ratio,    :float,           default: nil
  end

  @attrs ~w| node_id timestamp data_unique_sensors data_total data_valid_total data_valid_ratio |a
  @reqd ~w| node_id timestamp |a

  @doc false
  def changeset(data_log, params) do
    data_log
    |> cast(params, @attrs)
    |> validate_required(@reqd)
    |> unique_constraint(:node_id, name: :data_logs_uniq)
  end
end
