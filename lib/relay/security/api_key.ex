defmodule Relay.Security.ApiKey do
  @moduledoc """
  Hashes high-entropy API keys before persistence.

  API keys are credentials, so Relay never stores their plaintext form.
  """

  @spec hash(String.t()) :: String.t()
  def hash(api_key) when is_binary(api_key) do
    pepper = Application.fetch_env!(:relay, :api_key_pepper)

    :crypto.mac(:hmac, :sha256, pepper, api_key)
    |> Base.encode16(case: :lower)
  end
end
