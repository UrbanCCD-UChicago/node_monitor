defmodule NodeMonitor.Repo.Migrations.CreateNodes do
  use Ecto.Migration

  def change do
    create table(:nodes, primary_key: false) do
      add :id,              :string,          primary_key: true
      add :vsn,             :string,          null: true, default: nil
      add :lon,             :float,           null: true, default: nil
      add :lat,             :float,           null: true, default: nil
      add :address,         :string,          null: true, default: nil
      add :description,     :string,          null: true, default: nil
      add :start_timestamp, :naive_datetime,  null: true, default: nil
      add :end_timestamp,   :naive_datetime,  null: true, default: nil
    end
  end
end
