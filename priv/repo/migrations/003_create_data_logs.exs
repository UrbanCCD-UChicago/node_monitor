defmodule NodeMonitor.Repo.Migrations.CreateDataLogs do
  use Ecto.Migration

  def change do
    create table(:data_logs, primary_key: false) do
      add :node_id,             :string,          null: false
      add :timestamp,           :naive_datetime,  null: false
      add :data_unique_sensors, :integer,         null: true, default: nil
      add :data_total,          :integer,         null: true, default: nil
      add :data_valid_total,    :float,           null: true, default: nil
      add :data_valid_ratio,    :float,           null: true, default: nil
    end

    execute """
    SELECT create_hypertable('data_logs', 'timestamp', chunk_time_interval => interval '1 day')
    """

    create unique_index :data_logs, [:node_id, :timestamp], name: :data_logs_uniq

    create index :data_logs, :node_id

    create index :data_logs, :timestamp

    execute """
    CREATE MATERIALIZED VIEW latest_data_logs AS
      WITH q0 AS (
        SELECT node_id, timestamp, data_unique_sensors, data_total, data_valid_total, data_valid_ratio,
          row_number() OVER(
            PARTITION BY node_id
            ORDER BY timestamp DESC
          ) AS rn
        FROM data_logs
      )
      SELECT node_id, timestamp, data_unique_sensors, data_total, data_valid_total, data_valid_ratio
      FROM q0
      WHERE rn = 1
    """
  end
end
