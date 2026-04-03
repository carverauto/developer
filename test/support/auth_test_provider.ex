defmodule DeveloperPortal.Auth.TestProvider do
  @moduledoc false

  @behaviour DeveloperPortal.Auth.Provider

  @impl true
  def enabled?(opts), do: Keyword.get(opts, :enabled?, true)

  @impl true
  def authorize_url(_callback_url, state, _nonce, _code_verifier, _opts) do
    {:ok, "https://auth.example.test/oauth/authorize?state=#{state}"}
  end

  @impl true
  def fetch_user(
        %{"code" => "test-code", "state" => state},
        _callback_url,
        %{"state" => state},
        opts
      ) do
    {:ok, Keyword.fetch!(opts, :user)}
  end

  def fetch_user(_params, _callback_url, _session_data, _opts), do: {:error, :invalid_callback}
end
