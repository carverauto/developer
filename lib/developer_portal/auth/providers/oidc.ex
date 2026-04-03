defmodule DeveloperPortal.Auth.Providers.OIDC do
  @moduledoc false

  @behaviour DeveloperPortal.Auth.Provider

  @impl true
  def enabled?(opts) do
    present?(opts[:issuer]) and present?(opts[:client_id]) and present?(opts[:client_secret])
  end

  @impl true
  def authorize_url(callback_url, state, nonce, code_verifier, opts) do
    with {:ok, discovery} <- discovery(opts) do
      query =
        URI.encode_query(%{
          "client_id" => opts[:client_id],
          "redirect_uri" => callback_url,
          "response_type" => "code",
          "scope" => scopes(opts) |> Enum.join(" "),
          "state" => state,
          "nonce" => nonce,
          "code_challenge" => code_challenge(code_verifier),
          "code_challenge_method" => "S256"
        })

      {:ok, "#{discovery["authorization_endpoint"]}?#{query}"}
    end
  end

  @impl true
  def fetch_user(params, callback_url, session_data, opts) do
    with :ok <- validate_state(params, session_data),
         {:ok, discovery} <- discovery(opts),
         {:ok, token} <-
           exchange_code(discovery, params["code"], callback_url, session_data, opts),
         {:ok, userinfo} <- fetch_userinfo(discovery, token["access_token"], opts) do
      {:ok,
       %{
         "sub" => userinfo["sub"],
         "email" => userinfo["email"],
         "name" => userinfo["name"],
         "preferred_username" => userinfo["preferred_username"],
         "groups" => userinfo[opts[:groups_claim] || "groups"] || []
       }}
    end
  end

  defp discovery(opts) do
    issuer = String.trim_trailing(opts[:issuer] || "", "/")

    if issuer == "" do
      {:error, :missing_issuer}
    else
      discovery_url = issuer <> "/.well-known/openid-configuration"

      case Req.get(discovery_url, req_options(opts)) do
        {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
          {:ok, body}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:discovery_failed, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp exchange_code(discovery, code, callback_url, session_data, opts) when is_binary(code) do
    body = %{
      "grant_type" => "authorization_code",
      "code" => code,
      "redirect_uri" => callback_url,
      "client_id" => opts[:client_id],
      "client_secret" => opts[:client_secret],
      "code_verifier" => session_data["code_verifier"]
    }

    case Req.post(discovery["token_endpoint"], [form: body] ++ req_options(opts)) do
      {:ok, %Req.Response{status: 200, body: token}} when is_map(token) ->
        {:ok, token}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:token_exchange_failed, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp exchange_code(_discovery, _code, _callback_url, _session_data, _opts),
    do: {:error, :missing_code}

  defp fetch_userinfo(discovery, access_token, opts) when is_binary(access_token) do
    headers = [{"authorization", "Bearer " <> access_token}]

    case Req.get(discovery["userinfo_endpoint"], [headers: headers] ++ req_options(opts)) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:userinfo_failed, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_userinfo(_discovery, _access_token, _opts), do: {:error, :missing_access_token}

  defp validate_state(%{"state" => state}, %{"state" => state}) when is_binary(state), do: :ok
  defp validate_state(_params, _session_data), do: {:error, :invalid_state}

  defp code_challenge(code_verifier) do
    :sha256
    |> :crypto.hash(code_verifier)
    |> Base.url_encode64(padding: false)
  end

  defp scopes(opts) do
    Keyword.get(opts, :scopes, ["openid", "profile", "email"])
  end

  defp req_options(opts) do
    Keyword.get(opts, :req_options, [])
  end

  defp present?(value), do: is_binary(value) and value != ""
end
