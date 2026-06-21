defmodule RelayWeb.Router do
  use RelayWeb, :router

  pipeline :public_api do
    plug :accepts, ["json"]
    plug CORSPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
    plug RelayWeb.Plugs.AuthenticateApiKey
    plug RelayWeb.Plugs.RateLimit
  end

  pipeline :idempotent_write do
    plug RelayWeb.Plugs.RequireIdempotencyKey
  end

  scope "/health", RelayWeb do
    pipe_through :public_api

    get "/live", HealthController, :live
    get "/ready", HealthController, :ready
  end

  scope "/api/v1", RelayWeb do
    pipe_through :api

    get "/orders/:id", OrderController, :show
    get "/orders/:order_id/events", OrderController, :events

    scope "/" do
      pipe_through :idempotent_write

      post "/orders", OrderController, :create
      post "/orders/:id/transitions", OrderController, :transition
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:relay, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: RelayWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
