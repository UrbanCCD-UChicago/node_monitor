defmodule NodeMonitor.Repo do
  use Ecto.Repo,
    otp_app: :node_monitor,
    adapter: Ecto.Adapters.Postgres
end
