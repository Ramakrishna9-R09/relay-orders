defmodule Relay.Orders.OrderEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "order_events" do
    field :sequence, :integer
    field :event_type, :string
    field :data, :map, default: %{}
    field :actor, :string
    field :correlation_id, :string

    belongs_to :organization, Relay.Accounts.Organization
    belongs_to :order, Relay.Orders.Order
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :organization_id,
      :order_id,
      :sequence,
      :event_type,
      :data,
      :actor,
      :correlation_id
    ])
    |> validate_required([
      :organization_id,
      :order_id,
      :sequence,
      :event_type,
      :actor,
      :correlation_id
    ])
    |> unique_constraint([:order_id, :sequence])
  end
end
