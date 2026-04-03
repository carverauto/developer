defmodule DeveloperPortalWeb.AuthController do
  use DeveloperPortalWeb, :controller

  alias DeveloperPortal.Auth

  def login(conn, _params) do
    callback_url = callback_url()

    case Auth.begin_auth(conn, callback_url) do
      {:ok, conn, authorize_url} ->
        redirect(conn, external: authorize_url)

      {:error, :not_configured} ->
        conn
        |> put_flash(:error, "Authentik login is not configured for this environment.")
        |> redirect(to: ~p"/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Unable to start login: #{format_error(reason)}")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, params) do
    callback_url = callback_url()

    case Auth.finish_auth(conn, params, callback_url) do
      {:ok, conn} ->
        user = Auth.current_user(conn)
        info_message = signed_in_message(user)

        conn
        |> put_flash(:info, info_message)
        |> redirect(to: ~p"/")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Unable to complete login: #{format_error(reason)}")
        |> redirect(to: ~p"/")
    end
  end

  def logout(conn, _params) do
    conn
    |> Auth.log_out()
    |> put_flash(:info, "You have been signed out.")
    |> redirect(to: ~p"/")
  end

  defp callback_url do
    DeveloperPortalWeb.Endpoint.url() <> "/auth/callback"
  end

  defp signed_in_message(%{"name" => name, "portal_access" => true}),
    do: "Signed in as #{name}."

  defp signed_in_message(%{"name" => name}),
    do: "Signed in as #{name}, but the required Authentik group is not present."

  defp signed_in_message(_user), do: "Signed in."

  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error({type, status, _body}), do: "#{type}: #{status}"
  defp format_error(reason), do: inspect(reason)
end
