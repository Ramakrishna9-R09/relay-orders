alias Relay.Accounts.Organization
alias Relay.Repo
alias Relay.Security.ApiKey

development_key = System.get_env("RELAY_SEED_API_KEY", "relay_dev_sk_change_me_123456")

%Organization{}
|> Organization.changeset(%{
  name: "Acme Development",
  slug: "acme-development",
  api_key_hash: ApiKey.hash(development_key)
})
|> Repo.insert!(
  on_conflict: :nothing,
  conflict_target: :slug
)

IO.puts("""
Seeded development organization.
API key: #{development_key}

Change RELAY_SEED_API_KEY outside local development.
""")
