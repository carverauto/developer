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
    assert html =~ "Signed artifact"
    assert html =~ "registry.carverauto.dev/serviceradar/wasm-plugin-axis-camera:v1.2.99"
  end

  test "unsigned plugin detail renders the unsigned state without a pull command", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/plugins/dusk-checker")

    assert html =~ "Dusk Checker"
    assert html =~ "Unsigned artifact"
    refute html =~ "oras pull"
  end

  test "unknown plugin redirects back to the directory", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/plugins"}}} = live(conn, ~p"/plugins/does-not-exist")
  end
end
