defmodule DeveloperPortal.Auth do
  @moduledoc """
  Session-backed authentication helpers for Authentik-based sign-in.
  """

  @state_key "auth_state"
  @nonce_key "auth_nonce"
  @code_verifier_key "auth_code_verifier"
  @user_key "current_user"

  import Plug.Conn

  def enabled? do
    provider().enabled?(provider_opts())
  end

  def begin_auth(conn, callback_url) do
    if enabled?() do
      state = random_token()
      nonce = random_token()
      code_verifier = random_token(48)

      with {:ok, authorize_url} <-
             provider().authorize_url(callback_url, state, nonce, code_verifier, provider_opts()) do
        {:ok,
         conn
         |> put_session(@state_key, state)
         |> put_session(@nonce_key, nonce)
         |> put_session(@code_verifier_key, code_verifier), authorize_url}
      end
    else
      {:error, :not_configured}
    end
  end

  def finish_auth(conn, params, callback_url) do
    session_data = %{
      "state" => get_session(conn, @state_key),
      "nonce" => get_session(conn, @nonce_key),
      "code_verifier" => get_session(conn, @code_verifier_key)
    }

    with true <- enabled?() or {:error, :not_configured},
         {:ok, user} <- provider().fetch_user(params, callback_url, session_data, provider_opts()) do
      {:ok,
       conn
       |> clear_pending_auth()
       |> put_session(@user_key, normalize_user(user))}
    else
      false -> {:error, :not_configured}
      {:error, reason} -> {:error, reason}
    end
  end

  def log_out(conn) do
    conn
    |> clear_pending_auth()
    |> delete_session(@user_key)
  end

  def current_user(conn), do: get_session(conn, @user_key)

  def current_user_from_session(session), do: Map.get(session, @user_key)

  def normalize_user(user) do
    groups = user["groups"] || []
    required_group = required_group()

    %{
      "id" => user["id"] || user["sub"],
      "sub" => user["sub"] || user["id"],
      "email" => user["email"],
      "name" => user["name"] || user["preferred_username"] || user["email"],
      "preferred_username" => user["preferred_username"] || user["email"],
      "groups" => groups,
      "portal_access" => is_nil(required_group) or required_group in groups
    }
  end

  def required_group do
    Keyword.get(provider_opts(), :required_group)
  end

  def auth_enabled_assigns do
    %{auth_enabled: enabled?()}
  end

  defp clear_pending_auth(conn) do
    conn
    |> delete_session(@state_key)
    |> delete_session(@nonce_key)
    |> delete_session(@code_verifier_key)
  end

  defp provider do
    Application.get_env(:developer_portal, __MODULE__, [])
    |> Keyword.get(:provider, DeveloperPortal.Auth.Providers.OIDC)
  end

  defp provider_opts do
    Application.get_env(:developer_portal, __MODULE__, [])
    |> Keyword.get(:provider_opts, [])
  end

  defp random_token(length \\ 32) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
