defmodule RelayWeb.Plugs.AuthenticateApiKey do
  @moduledoc "Authenticates a tenant from a hashed Bearer API key."

  import Plug.Conn

  alias Relay.Accounts

  def init(options), do: options

  def call(conn, _options) do
    with ["Bearer " <> api_key] <- get_req_header(conn, "authorization"),
         organization when not is_nil(organization) <-
           Accounts.get_active_organization_by_api_key(api_key) do
      conn
      |> assign(:current_organization, organization)
      |> put_private(:logger_metadata, %{organization_id: organization.id})
    else
      _reason ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{
          error: %{
            code: "unauthorized",
            message: "Provide a valid Bearer API key."
          }
        })
        |> halt()
    end
  end
end
