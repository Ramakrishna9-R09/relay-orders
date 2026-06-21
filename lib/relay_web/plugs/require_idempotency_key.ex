defmodule RelayWeb.Plugs.RequireIdempotencyKey do
  @moduledoc "Requires a bounded idempotency key on mutating endpoints."

  import Plug.Conn

  def init(options), do: options

  def call(conn, _options) do
    case get_req_header(conn, "idempotency-key") do
      [key] when byte_size(key) >= 8 and byte_size(key) <= 255 ->
        assign(conn, :idempotency_key, key)

      _other ->
        conn
        |> put_status(:unprocessable_entity)
        |> Phoenix.Controller.json(%{
          error: %{
            code: "missing_idempotency_key",
            message: "Idempotency-Key header must contain 8 to 255 characters."
          }
        })
        |> halt()
    end
  end
end
