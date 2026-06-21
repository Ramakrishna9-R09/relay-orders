defmodule Relay.Accounts.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :api_key_hash, :string, redact: true
    field :status, Ecto.Enum, values: [:active, :suspended], default: :active

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug, :api_key_hash, :status])
    |> validate_required([:name, :slug, :api_key_hash])
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> unique_constraint(:slug)
    |> unique_constraint(:api_key_hash)
  end
end
