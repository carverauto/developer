defmodule DeveloperPortalWeb.AuthControllerTest do
  use DeveloperPortalWeb.ConnCase, async: true

  test "login redirects to authentik provider", %{conn: conn} do
    conn = get(conn, ~p"/auth/login")

    redirect_url = redirected_to(conn, 302)
    assert redirect_url =~ "https://auth.example.test/oauth/authorize?state="
    assert get_session(conn, "auth_state")
    assert get_session(conn, "auth_code_verifier")
  end

  test "callback stores current user in the session", %{conn: conn} do
    conn = get(conn, ~p"/auth/login")
    state = get_session(conn, "auth_state")

    conn =
      conn
      |> recycle()
      |> get(~p"/auth/callback?code=test-code&state=#{state}")

    assert redirected_to(conn) == "/"

    assert %{"email" => "dev@example.com", "portal_access" => true} =
             get_session(conn, "current_user")
  end

  test "logout clears the current user session", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{
        "current_user" => %{"name" => "Portal Developer", "portal_access" => true}
      })
      |> post(~p"/auth/logout")

    assert redirected_to(conn) == "/"
    refute get_session(conn, "current_user")
  end
end
