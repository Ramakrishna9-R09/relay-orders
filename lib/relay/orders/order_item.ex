defmodule Relay.Orders.OrderItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "order_items" do
    field :sku, :string
    field :name, :string
    field :unit_price, :decimal
    field :quantity, :integer

    belongs_to :order, Relay.Orders.Order
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:sku, :name, :unit_price, :quantity])
    |> validate_required([:sku, :name, :unit_price, :quantity])
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> validate_number(:quantity, greater_than: 0, less_than_or_equal_to: 10_000)
    |> validate_length(:sku, max: 100)
  end
end
