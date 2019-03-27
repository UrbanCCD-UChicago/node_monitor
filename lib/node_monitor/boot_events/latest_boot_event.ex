defmodule NodeMonitor.BootEvents.LatestBootEvent do
  use Ecto.Schema

  @primary_key false
  schema "latest_boot_events" do
    field :node_id,   :string
    field :timestamp, :naive_datetime
    field :boot_id,   :string
    field :media,     :string
  end
end
