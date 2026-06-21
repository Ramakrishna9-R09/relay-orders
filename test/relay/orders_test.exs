defmodule Relay.OrdersTest do
  use Relay.DataCase

  alias Relay.Accounts.Organization
  alias Relay.Orders

  setup do
    organization =
      Repo.insert!(%Organization{
        name: "Test Organization",
        slug: "test-#{System.unique_integer([:positive])}",
        api_key_hash: "hash-#{System.unique_integer([:positive])}"
      })

    %{organization: organization}
  end

  test "creates, audits, and idempotently replays an order", %{organization: organization} do
    attrs = valid_order_attrs()
    options = [idempotency_key: "create-order-0001", correlation_id: Ecto.UUID.generate()]

    assert {:ok, order, :created} = Orders.create_order(organization, attrs, options)
    assert order.status == :pending
    assert order.total_amount == Decimal.new("25.00")

    assert {:ok, replayed, :replayed} = Orders.create_order(organization, attrs, options)
    assert replayed.id == order.id

    assert [%{event_type: "order.created", sequence: 1}] =
             Orders.list_events(organization, order.id)
  end

  test "serializes transitions and rejects invalid commands", %{organization: organization} do
    {:ok, order, :created} =
      Orders.create_order(organization, valid_order_attrs(),
        idempotency_key: "create-order-0002",
        correlation_id: Ecto.UUID.generate()
      )

    assert {:error, {:invalid_transition, :pending, :ship}} =
             Orders.transition_order(organization, order.id, :ship,
               idempotency_key: "ship-order-0002",
               correlation_id: Ecto.UUID.generate()
             )

    assert {:ok, paid, :updated} =
             Orders.transition_order(organization, order.id, :pay,
               idempotency_key: "pay-order-0002",
               correlation_id: Ecto.UUID.generate()
             )

    assert paid.status == :paid
    assert paid.version == 2
  end

  test "rejects an idempotency key reused with different input", %{
    organization: organization
  } do
    options = [
      idempotency_key: "reused-key-0001",
      correlation_id: Ecto.UUID.generate()
    ]

    assert {:ok, _order, :created} =
             Orders.create_order(organization, valid_order_attrs(), options)

    changed_attrs =
      valid_order_attrs()
      |> Map.put("customer_email", "different@example.com")

    assert {:error, :idempotency_key_reused} =
             Orders.create_order(organization, changed_attrs, options)
  end

  test "does not expose an order to another organization", %{organization: organization} do
    other_organization =
      Repo.insert!(%Organization{
        name: "Other Organization",
        slug: "other-#{System.unique_integer([:positive])}",
        api_key_hash: "other-hash-#{System.unique_integer([:positive])}"
      })

    assert {:ok, order, :created} =
             Orders.create_order(organization, valid_order_attrs(),
               idempotency_key: "tenant-order-0001",
               correlation_id: Ecto.UUID.generate()
             )

    assert Orders.get_order(other_organization, order.id) == nil
    assert Orders.list_events(other_organization, order.id) == []
  end

  defp valid_order_attrs do
    %{
      "external_id" => "external-#{System.unique_integer([:positive])}",
      "customer_email" => "buyer@example.com",
      "currency" => "USD",
      "items" => [
        %{
          "sku" => "PRO-1",
          "name" => "Professional Plan",
          "unit_price" => "12.50",
          "quantity" => 2
        }
      ]
    }
  end
end
