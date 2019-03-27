defmodule NodeMonitor.TTL do
  alias NodeMonitor.Repo

  def purge_old_boot_events do
    Repo.transaction(fn ->
      Repo.query!("DELETE FROM boot_events WHERE timestamp < now() - '7 days'::interval")
      Repo.query!("REFRESH MATERIALIZED VIEW latest_boot_events")
    end)
  end

  def purge_old_data_logs do
    Repo.transaction(fn ->
      Repo.query!("DELETE FROM data_logs WHERE timestamp < now() - '7 days'::interval")
      Repo.query!("REFRESH MATERIALIZED VIEW latest_data_logs")
    end)
  end

  def purge_old_status_logs do
    Repo.transaction(fn ->
      Repo.query!("DELETE FROM status_logs WHERE timestamp < now() - interval '7 days'")
      Repo.query!("REFRESH MATERIALIZED VIEW latest_status_logs")
    end)
  end
end
