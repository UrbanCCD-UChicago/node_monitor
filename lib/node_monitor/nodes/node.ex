defmodule NodeMonitor.Nodes.Node do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key{:id, :string, autogenerate: false}
  schema "nodes" do
    field :vsn,             :string,          default: nil
    field :lon,             :float,           default: nil
    field :lat,             :float,           default: nil
    field :address,         :string,          default: nil
    field :description,     :string,          default: nil
    field :start_timestamp, :naive_datetime,  default: nil
    field :end_timestamp,   :naive_datetime,  default: nil
  end

  @attrs ~w| id vsn lon lat address description start_timestamp end_timestamp |a
  @reqd ~w| id vsn |a

  @doc false
  def changeset(node, params) do
    node
    |> cast(params, @attrs)
    |> validate_required(@reqd)
    |> unique_constraint(:id, name: :nodes_pkey)
  end
end
