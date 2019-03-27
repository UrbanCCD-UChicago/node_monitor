defmodule NodeMonitor.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      # Start the Ecto repository
      supervisor(NodeMonitor.Repo, []),

      # Start the endpoint when the application starts
      supervisor(NodeMonitorWeb.Endpoint, []),

      worker(NodeMonitor.Scheduler, [])
    ]

    opts = [strategy: :one_for_one, name: NodeMonitor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    NodeMonitorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
