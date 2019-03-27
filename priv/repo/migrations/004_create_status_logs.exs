defmodule NodeMonitor.Repo.Migrations.CreateStatusLogs do
  use Ecto.Migration

  def change do
    create table(:status_logs, primary_key: false) do
      add :node_id,             :string,          null: false
      add :timestamp,           :naive_datetime,  null: false

      # nc uptimes
      add :up_nc_sys,           :bigint,          null: true, default: nil
      add :up_nc_wm,            :bigint,          null: true, default: nil
      add :up_nc_cs,            :bigint,          null: true, default: nil
      add :up_nc_modem,         :bigint,          null: true, default: nil
      add :up_nc_wwan,          :bigint,          null: true, default: nil
      add :up_nc_lan,           :bigint,          null: true, default: nil
      add :up_nc_mic,           :bigint,          null: true, default: nil
      add :up_nc_samba,         :boolean,         null: true, default: nil

      # epoch
      add :epoch_nc,            :naive_datetime,  null: true, default: nil
      add :epoch_ep,            :naive_datetime,  null: true, default: nil

      # nc software flags
      add :run_nc_rabbitmq,     :boolean,         null: true, default: nil
      add :"run_nc_cs-plugin",  :boolean,         null: true, default: nil

      # fail counts
      add :fc_nc,               :integer,         null: true, default: nil
      add :fc_ep,               :integer,         null: true, default: nil
      add :fc_cs,               :integer,         null: true, default: nil

      # current usage
      add :cu_nc,               :integer,         null: true, default: nil
      add :cu_ep,               :integer,         null: true, default: nil
      add :cu_wm,               :integer,         null: true, default: nil
      add :cu_cs,               :integer,         null: true, default: nil

      # device en
      add :en_nc,               :boolean,         null: true, default: nil
      add :en_ep,               :boolean,         null: true, default: nil
      add :en_cs,               :boolean,         null: true, default: nil

      # heart beats
      add :hb_nc,               :boolean,         null: true, default: nil
      add :hb_ep,               :boolean,         null: true, default: nil
      add :hb_cs,               :boolean,         null: true, default: nil

      # edge processor uptimes
      add :up_ep_sys,           :bigint,          null: true, default: nil
      add :up_ep_bcam,          :bigint,          null: true, default: nil
      add :up_ep_tcam,          :bigint,          null: true, default: nil
      add :up_ep_mic,           :bigint,          null: true, default: nil

      # edge processor software flags
      add :run_ep_rabbitmq,     :boolean,         null: true, default: nil

      # other
      add :up_wm_sys,           :bigint,          null: true, default: nil
      add :net_wwan,            :bigint,          null: true, default: nil
    end

    execute """
    SELECT create_hypertable('status_logs', 'timestamp', chunk_time_interval => interval '1 day')
    """

    create unique_index :status_logs, [:node_id, :timestamp], name: :status_logs_uniq

    create index :status_logs, :node_id

    create index :status_logs, :timestamp

    execute """
    CREATE MATERIALIZED VIEW latest_status_logs AS
      WITH q0 AS (
        SELECT
          node_id, timestamp, up_nc_sys, up_nc_wm, up_nc_cs, up_nc_modem, up_nc_wwan, up_nc_lan, up_nc_mic, up_nc_samba, epoch_nc, epoch_ep, run_nc_rabbitmq, "run_nc_cs-plugin", fc_nc, fc_ep, fc_cs, cu_nc, cu_ep, cu_wm, cu_cs, en_nc, en_ep, en_cs, hb_nc, hb_ep, hb_cs, up_ep_sys, up_ep_bcam, up_ep_tcam, up_ep_mic, run_ep_rabbitmq, up_wm_sys, net_wwan,
          row_number() OVER(
            PARTITION BY node_id
            ORDER BY timestamp DESC
          ) AS rn
        FROM status_logs
      )
      SELECT node_id, timestamp, up_nc_sys, up_nc_wm, up_nc_cs, up_nc_modem, up_nc_wwan, up_nc_lan, up_nc_mic, up_nc_samba, epoch_nc, epoch_ep, run_nc_rabbitmq, "run_nc_cs-plugin", fc_nc, fc_ep, fc_cs, cu_nc, cu_ep, cu_wm, cu_cs, en_nc, en_ep, en_cs, hb_nc, hb_ep, hb_cs, up_ep_sys, up_ep_bcam, up_ep_tcam, up_ep_mic, run_ep_rabbitmq, up_wm_sys, net_wwan
      FROM q0
      WHERE rn = 1
    """
  end
end
