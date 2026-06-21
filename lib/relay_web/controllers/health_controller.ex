defmodule RelayWeb.HealthController do
  use RelayWeb, :controller

  alias Relay.Repo

  def live(conn, _params), do: json(conn, %{status: "ok"})

  def ready(conn, _params) do
    case Repo.query("SELECT 1", [], timeout: 1_000) do
      {:ok, _result} ->
        json(conn, %{status: "ready"})

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "not_ready"})
    end
  end
end
