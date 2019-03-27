defmodule NodeMonitor.Repo.Migrations.EnableTimescaledb do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb"
  end
end
