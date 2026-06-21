defmodule Relay.Repo.Migrations.CreateRelayCore do
  use Ecto.Migration

  def up do
    Oban.Migrations.up()

    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :api_key_hash, :string, null: false
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organizations, [:slug])
    create unique_index(:organizations, [:api_key_hash])

    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict),
        null: false

      add :external_id, :string, null: false
      add :customer_email, :string, null: false
      add :currency, :string, size: 3, null: false
      add :total_amount, :decimal, precision: 18, scale: 2, null: false
      add :status, :string, null: false, default: "pending"
      add :version, :integer, null: false, default: 1
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:orders, [:organization_id, :external_id])
    create index(:orders, [:organization_id, :status, :inserted_at])

    create constraint(:orders, :positive_order_version, check: "version > 0")
    create constraint(:orders, :non_negative_total, check: "total_amount >= 0")

    create table(:order_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false
      add :sku, :string, null: false
      add :name, :string, null: false
      add :unit_price, :decimal, precision: 18, scale: 2, null: false
      add :quantity, :integer, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:order_items, [:order_id])
    create constraint(:order_items, :positive_quantity, check: "quantity > 0")
    create constraint(:order_items, :non_negative_unit_price, check: "unit_price >= 0")

    create table(:order_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict),
        null: false

      add :order_id, references(:orders, type: :binary_id, on_delete: :restrict), null: false
      add :sequence, :integer, null: false
      add :event_type, :string, null: false
      add :data, :map, null: false, default: %{}
      add :actor, :string, null: false
      add :correlation_id, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:order_events, [:order_id, :sequence])
    create index(:order_events, [:organization_id, :inserted_at])
    create index(:order_events, [:correlation_id])

    create table(:idempotency_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :key, :string, null: false
      add :request_hash, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :binary_id, null: false
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:idempotency_keys, [:organization_id, :key])
    create index(:idempotency_keys, [:expires_at])
  end

  def down do
    drop table(:idempotency_keys)
    drop table(:order_events)
    drop table(:order_items)
    drop table(:orders)
    drop table(:organizations)

    Oban.Migrations.down()
  end
end
