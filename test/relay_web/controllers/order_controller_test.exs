defmodule RelayWeb.OrderControllerTest do
  use RelayWeb.ConnCase

  alias Relay.Accounts.Organization
  alias Relay.Orders
  alias Relay.Repo
  alias Relay.Security.ApiKey

  @api_key "relay_test_sk_professional_123456"

  setup do
    organization =
      Repo.insert!(%Organization{
        name: "API Test Organization",
        slug: "api-test-#{System.unique_integer([:positive])}",
        api_key_hash: ApiKey.hash(@api_key)
      })

    %{organization: organization}
  end

  test "health checks remain public", %{conn: conn} do
    assert %{"status" => "ok"} =
             conn
             |> get(~p"/health/live")
             |> json_response(200)
  end

  test "rejects unauthenticated access", %{conn: conn} do
    response =
      conn
      |> get(~p"/api/v1/orders/#{Ecto.UUID.generate()}")
      |> json_response(401)

    assert response["error"]["code"] == "unauthorized"
  end

  test "creates and idempotently replays through the HTTP boundary", %{conn: conn} do
    body = %{
      "order" => %{
        "external_id" => "http-#{System.unique_integer([:positive])}",
        "customer_email" => "buyer@example.com",
        "currency" => "USD",
        "items" => [
          %{
            "sku" => "ELIXIR-PRO",
            "name" => "Elixir Professional",
            "unit_price" => "99.00",
            "quantity" => 1
          }
        ]
      }
    }

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@api_key}")
      |> put_req_header("idempotency-key", "http-create-order-0001")
      |> post(~p"/api/v1/orders", body)

    response = json_response(conn, 201)
    assert response["data"]["status"] == "pending"
    assert get_resp_header(conn, "idempotent-replayed") == ["false"]

    replay_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{@api_key}")
      |> put_req_header("idempotency-key", "http-create-order-0001")
      |> post(~p"/api/v1/orders", body)

    replay = json_response(replay_conn, 200)
    assert replay["data"]["id"] == response["data"]["id"]
    assert get_resp_header(replay_conn, "idempotent-replayed") == ["true"]
  end

  test "preserves request correlation through the audit event", %{
    conn: conn,
    organization: organization
  } do
    correlation_id = "request-correlation-0001"

    body = %{
      "order" => %{
        "external_id" => "correlated-#{System.unique_integer([:positive])}",
        "customer_email" => "buyer@example.com",
        "currency" => "USD",
        "items" => [
          %{
            "sku" => "TRACE-1",
            "name" => "Traceable Order",
            "unit_price" => "10.00",
            "quantity" => 1
          }
        ]
      }
    }

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{@api_key}")
      |> put_req_header("idempotency-key", "correlated-order-0001")
      |> put_req_header("x-request-id", correlation_id)
      |> post(~p"/api/v1/orders", body)

    order_id = json_response(conn, 201)["data"]["id"]

    assert get_resp_header(conn, "x-request-id") == [correlation_id]

    assert [%{correlation_id: ^correlation_id}] =
             Orders.list_events(organization, order_id)
  end
end
