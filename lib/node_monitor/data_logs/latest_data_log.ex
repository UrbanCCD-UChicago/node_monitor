defmodule NodeMonitor.DataLogs.LatestDataLog do
  use Ecto.Schema

  @primary_key false
  schema "latest_data_logs" do
    field :node_id,             :string
    field :timestamp,           :naive_datetime
    field :data_unique_sensors, :integer
    field :data_total,          :integer
    field :data_valid_total,    :float
    field :data_valid_ratio,    :float
  end
end
