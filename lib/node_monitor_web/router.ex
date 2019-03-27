defmodule NodeMonitorWeb.Router do
  use NodeMonitorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", NodeMonitorWeb do
    pipe_through :browser

    # landing pages
    get "/", NodesController, :all_nodes
    get "/overview", NodesController, :overview
    get "/map", NodesController, :map

    # node detail pages
    get "/nodes/:id", NodesController, :show
  end
end
