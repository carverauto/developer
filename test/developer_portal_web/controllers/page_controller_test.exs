defmodule DeveloperPortalWeb.PageControllerTest do
  use DeveloperPortalWeb.ConnCase, async: true

  test "GET / renders the developer portal home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "ServiceRadar Developer Portal"
    assert html =~ "Build, publish, and discover ServiceRadar extensions"
  end

  test "GET /docs/v1 renders the v1 docs page", %{conn: conn} do
    conn = get(conn, ~p"/docs/v1")
    html = html_response(conn, 200)

    assert html =~ "ServiceRadar V1 developer documentation"
    assert html =~ "Go SDK"
    assert html =~ "Rust SDK"
  end

  test "GET /contribute renders the contribution guide", %{conn: conn} do
    conn = get(conn, ~p"/contribute")
    html = html_response(conn, 200)

    assert html =~ "Submit a plugin through a reviewed PR"
    assert html =~ "Required package contents"
  end
end
