defmodule Relay.Accounts do
  @moduledoc "Tenant and credential boundary."

  import Ecto.Query

  alias Relay.Accounts.Organization
  alias Relay.Repo
  alias Relay.Security.ApiKey

  def get_active_organization_by_api_key(api_key) when is_binary(api_key) do
    hash = ApiKey.hash(api_key)

    Repo.one(
      from organization in Organization,
        where:
          organization.api_key_hash == ^hash and
            organization.status == :active
    )
  end
end
