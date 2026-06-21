defmodule RelayWeb.Plugs.RateLimit do
  @moduledoc "Applies the node-local per-tenant request limit."

  import Plug.Conn

  alias Relay.Security.RateLimiter

  def init(options), do: options

  def call(conn, _options) do
    limit = Application.get_env(:relay, :requests_per_minute, 120)
    organization = conn.assigns.current_organization

    if RateLimiter.allow?(organization.id, limit) do
      conn
    else
      conn
      |> put_resp_header("retry-after", "60")
      |> put_status(:too_many_requests)
      |> Phoenix.Controller.json(%{
        error: %{
          code: "rate_limit_exceeded",
          message: "Request limit exceeded. Retry after 60 seconds."
        }
      })
      |> halt()
    end
  end
end
