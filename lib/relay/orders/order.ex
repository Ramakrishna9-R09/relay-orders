defmodule Relay.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  alias Relay.Accounts.Organization
  alias Relay.Orders.{OrderEvent, OrderItem}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "orders" do
    field :external_id, :string
    field :customer_email, :string
    field :currency, :string, default: "USD"
    field :total_amount, :decimal

    field :status, Ecto.Enum,
      values: [:pending, :paid, :packed, :shipped, :delivered, :cancelled],
      default: :pending

    field :version, :integer, default: 1
    field :metadata, :map, default: %{}

    belongs_to :organization, Organization
    has_many :items, OrderItem, on_replace: :delete
    has_many :events, OrderEvent

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(order, attrs) do
    order
    |> cast(attrs, [:external_id, :customer_email, :currency, :metadata])
    |> cast_assoc(:items, required: true, with: &OrderItem.changeset/2)
    |> validate_required([:external_id, :customer_email, :currency])
    |> validate_format(:customer_email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_format(:currency, ~r/^[A-Z]{3}$/)
    |> validate_length(:external_id, min: 1, max: 100)
    |> validate_length(:metadata, max: 50)
    |> calculate_total()
    |> unique_constraint([:organization_id, :external_id])
  end

  def transition_changeset(order, next_status) do
    change(order, status: next_status, version: order.version + 1)
  end

  defp calculate_total(changeset) do
    items = get_change(changeset, :items, [])

    total =
      Enum.reduce(items, Decimal.new(0), fn item_changeset, sum ->
        price = get_field(item_changeset, :unit_price) || Decimal.new(0)
        quantity = get_field(item_changeset, :quantity) || 0
        Decimal.add(sum, Decimal.mult(price, quantity))
      end)

    put_change(changeset, :total_amount, total)
  end
end
