# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :node_monitor,
  ecto_repos: [NodeMonitor.Repo]

# Configures the endpoint
config :node_monitor, NodeMonitorWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "OhLUv60I9uu5n5fT66RVv+8wtevYcyejXxpCMfENbxVZwZLpr0xwZ2HVLYXyKRjc",
  render_errors: [view: NodeMonitorWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: NodeMonitor.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure import jobs
config :node_monitor, NodeMonitor.Scheduler, jobs: [
  {"*/10 * * * *", {NodeMonitor.Nodes, :load_recent_tarballs, []}},

  {"*/10 * * * *", {NodeMonitor.BootEvents, :load_boot_events, []}},
  {"*/10 * * * *", {NodeMonitor.DataLogs, :load_data_logs, []}},
  {"*/10 * * * *", {NodeMonitor.StatusLogs, :load_status_logs, []}},

  {"1 0 * * *", {NodeMonitor.TTL, :purge_old_boot_events, []}},
  {"1 0 * * *", {NodeMonitor.TTL, :purge_old_data_logs, []}},
  {"1 0 * * *", {NodeMonitor.TTL, :purge_old_status_logs, []}}
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
