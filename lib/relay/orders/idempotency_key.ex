defmodule Relay.Orders.IdempotencyKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "idempotency_keys" do
    field :key, :string
    field :request_hash, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :expires_at, :utc_datetime_usec

    belongs_to :organization, Relay.Accounts.Organization
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :organization_id,
      :key,
      :request_hash,
      :resource_type,
      :resource_id,
      :expires_at
    ])
    |> validate_required([
      :organization_id,
      :key,
      :request_hash,
      :resource_type,
      :resource_id,
      :expires_at
    ])
    |> validate_length(:key, min: 8, max: 255)
    |> unique_constraint([:organization_id, :key])
  end
end
