defmodule NodeMonitor.BootEvents.BootEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "boot_events" do
    field :node_id,   :string
    field :timestamp, :naive_datetime
    field :boot_id,   :string,          default: nil
    field :media,     :string
  end

  @attrs ~w| node_id timestamp boot_id media |a
  @reqd ~w| node_id timestamp media |a

  @doc false
  def changeset(boot_event, params) do
    boot_event
    |> cast(params, @attrs)
    |> validate_required(@reqd)
    |> unique_constraint(:node_id, name: :boot_events_uniq)
  end
end
