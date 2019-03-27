defmodule NodeMonitor.Repo.Migrations.CreateBootEvents do
  use Ecto.Migration

  def change do
    create table(:boot_events, primary_key: false) do
      add :node_id,   :string,          null: false
      add :timestamp, :naive_datetime,  null: false
      add :boot_id,   :string,          null: true, default: nil
      add :media,     :string,          null: false
    end

    execute """
    SELECT create_hypertable('boot_events', 'timestamp', chunk_time_interval => interval '1 day')
    """

    create unique_index :boot_events, [:node_id, :timestamp], name: :boot_events_uniq

    create index :boot_events, :node_id

    create index :boot_events, :timestamp

    execute """
    CREATE MATERIALIZED VIEW latest_boot_events AS
      WITH q0 AS (
        SELECT
          node_id, timestamp, boot_id, media,
          row_number() OVER(
            PARTITION BY node_id
            ORDER BY timestamp DESC
          ) AS rn
        FROM boot_events
      )
      SELECT node_id, timestamp, boot_id, media
      FROM q0
      WHERE rn = 1
    """
  end
end
