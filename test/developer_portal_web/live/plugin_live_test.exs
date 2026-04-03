defmodule DeveloperPortalWeb.PluginLiveTest do
  use DeveloperPortalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "plugin directory renders and filters", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/plugins")

    assert html =~ "Official and community plugins"
    assert html =~ "AXIS Camera"

    html =
      view
      |> form("#plugin-filters",
        filters: %{"q" => "Dusk", "type" => "", "language" => "", "category" => ""}
      )
      |> render_change()

    assert html =~ "Dusk Checker"
  end

  test "plugin detail page renders", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/plugins/axis-camera")

    assert html =~ "AXIS Camera"
    assert html =~ "wasi-preview1"
    assert html =~ "run_check"
  end

  test "signed in user is visible in live layout", %{conn: conn} do
    conn =
      init_test_session(conn, %{
        "current_user" => %{
          "name" => "Portal Developer",
          "email" => "dev@example.com",
          "portal_access" => true,
          "groups" => ["serviceradar-developer"]
        }
      })

    {:ok, _view, html} = live(conn, ~p"/plugins")

    assert html =~ "Portal Developer"
    assert html =~ "Log out"
  end
end
