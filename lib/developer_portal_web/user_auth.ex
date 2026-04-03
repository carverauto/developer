defmodule DeveloperPortalWeb.UserAuth do
  @moduledoc false

  import Plug.Conn

  alias DeveloperPortal.Auth

  def fetch_current_user(conn, _opts) do
    conn
    |> assign(:current_user, Auth.current_user(conn))
    |> assign(:auth_enabled, Auth.enabled?())
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont,
     socket
     |> Phoenix.Component.assign(:current_user, Auth.current_user_from_session(session))
     |> Phoenix.Component.assign(:auth_enabled, Auth.enabled?())}
  end
end
