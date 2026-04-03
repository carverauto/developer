defmodule DeveloperPortal.Auth.Provider do
  @moduledoc false

  @callback enabled?(keyword()) :: boolean()

  @callback authorize_url(
              callback_url :: binary(),
              state :: binary(),
              nonce :: binary(),
              code_verifier :: binary(),
              opts :: keyword()
            ) :: {:ok, binary()} | {:error, term()}

  @callback fetch_user(
              params :: map(),
              callback_url :: binary(),
              session_data :: map(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, term()}
end
