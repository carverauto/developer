defmodule DeveloperPortalWeb.AddonLiveTest do
  use DeveloperPortalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "add-on catalog renders and filters", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/addons")

    assert html =~ "Published, signed native add-ons"
    assert html =~ "Host Network Visibility"

    html =
      view
      |> form("#addon-filters",
        filters: %{"q" => "Sample", "language" => "", "supervision" => ""}
      )
      |> render_change()

    assert html =~ "Sample Add-on"
    refute html =~ "Host Network Visibility"
  end

  test "add-on detail page renders signing metadata", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/addons/netprobe")

    assert html =~ "Host Network Visibility"
    assert html =~ "Signed artifact"
    assert html =~ "registry.carverauto.dev/serviceradar/serviceradar-addon-netprobe:v1.2.99"
    assert html =~ "linux/amd64"
  end

  test "unsigned add-on detail renders the unsigned state without a pull command", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/addons/preview-collector")

    assert html =~ "Preview Collector"
    assert html =~ "Unsigned artifact"
    refute html =~ "oras pull"
  end

  test "unknown add-on redirects back to the catalog", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/addons"}}} = live(conn, ~p"/addons/does-not-exist")
  end
end
