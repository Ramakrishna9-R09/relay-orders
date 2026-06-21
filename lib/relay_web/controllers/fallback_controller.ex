defmodule RelayWeb.FallbackController do
  use RelayWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "validation_failed",
        message: "The request contains invalid data.",
        details: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
      }
    })
  end

  def call(conn, {:error, :not_found}),
    do: error(conn, :not_found, "not_found", "Order not found.")

  def call(conn, {:error, :idempotency_key_reused}) do
    error(
      conn,
      :conflict,
      "idempotency_key_reused",
      "This idempotency key was already used for a different request."
    )
  end

  def call(conn, {:error, :concurrent_request}) do
    error(
      conn,
      :conflict,
      "concurrent_request",
      "An identical request is still being processed. Retry shortly."
    )
  end

  def call(conn, {:error, {:invalid_transition, current, command}}) do
    error(
      conn,
      :conflict,
      "invalid_transition",
      "Cannot #{command} an order in #{current} status."
    )
  end

  def call(conn, {:error, {:unknown_command, command}}) do
    error(conn, :unprocessable_entity, "unknown_command", "Unknown command: #{command}.")
  end

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end

  defp translate_error({message, options}) do
    Enum.reduce(options, message, fn {key, value}, translated ->
      String.replace(translated, "%{#{key}}", to_string(value))
    end)
  end
end
