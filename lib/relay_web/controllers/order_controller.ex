defmodule RelayWeb.OrderController do
  use RelayWeb, :controller

  alias Relay.Orders
  alias Relay.Orders.StateMachine

  action_fallback RelayWeb.FallbackController

  def create(conn, %{"order" => attributes}) do
    with {:ok, order, outcome} <-
           Orders.create_order(conn.assigns.current_organization, attributes,
             idempotency_key: conn.assigns.idempotency_key,
             correlation_id: correlation_id(conn)
           ) do
      status = if outcome == :created, do: :created, else: :ok

      conn
      |> put_status(status)
      |> put_resp_header("location", ~p"/api/v1/orders/#{order.id}")
      |> put_resp_header("idempotent-replayed", to_string(outcome == :replayed))
      |> json(%{data: serialize_order(order)})
    end
  end

  def create(_conn, _params),
    do:
      {:error,
       Ecto.Changeset.change(%Relay.Orders.Order{})
       |> Ecto.Changeset.add_error(:order, "is required")}

  def show(conn, %{"id" => id}) do
    case Orders.get_order(conn.assigns.current_organization, id) do
      nil -> {:error, :not_found}
      order -> json(conn, %{data: serialize_order(order)})
    end
  end

  def transition(conn, %{"id" => id, "command" => command}) do
    with {:ok, command_atom} <- parse_command(command),
         {:ok, order, outcome} <-
           Orders.transition_order(
             conn.assigns.current_organization,
             id,
             command_atom,
             idempotency_key: conn.assigns.idempotency_key,
             correlation_id: correlation_id(conn)
           ) do
      conn
      |> put_resp_header("idempotent-replayed", to_string(outcome == :replayed))
      |> json(%{data: serialize_order(order)})
    end
  end

  def events(conn, %{"order_id" => order_id}) do
    case Orders.get_order(conn.assigns.current_organization, order_id) do
      nil ->
        {:error, :not_found}

      _order ->
        events = Orders.list_events(conn.assigns.current_organization, order_id)
        json(conn, %{data: Enum.map(events, &serialize_event/1)})
    end
  end

  defp parse_command(command) when is_binary(command) do
    case Enum.find(StateMachine.commands(), &(Atom.to_string(&1) == command)) do
      nil -> {:error, {:unknown_command, command}}
      known -> {:ok, known}
    end
  end

  defp serialize_order(order) do
    %{
      id: order.id,
      external_id: order.external_id,
      customer_email: order.customer_email,
      currency: order.currency,
      total_amount: Decimal.to_string(order.total_amount),
      status: order.status,
      version: order.version,
      metadata: order.metadata,
      items:
        Enum.map(order.items, fn item ->
          %{
            id: item.id,
            sku: item.sku,
            name: item.name,
            unit_price: Decimal.to_string(item.unit_price),
            quantity: item.quantity
          }
        end),
      inserted_at: order.inserted_at,
      updated_at: order.updated_at
    }
  end

  defp serialize_event(event) do
    %{
      id: event.id,
      sequence: event.sequence,
      type: event.event_type,
      data: event.data,
      actor: event.actor,
      correlation_id: event.correlation_id,
      occurred_at: event.inserted_at
    }
  end

  defp correlation_id(conn) do
    List.first(get_req_header(conn, "x-request-id")) || Ecto.UUID.generate()
  end
end
