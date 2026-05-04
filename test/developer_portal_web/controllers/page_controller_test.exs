defmodule DeveloperPortalWeb.PageControllerTest do
  use DeveloperPortalWeb.ConnCase, async: true

  test "GET / renders the developer portal home page", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "ServiceRadar Developer Portal"
    assert html =~ "Build, publish, and discover ServiceRadar extensions"
  end

  test "GET /docs/v1 redirects to the v2 docs page", %{conn: conn} do
    conn = get(conn, ~p"/docs/v1")

    assert redirected_to(conn) == "/docs/v2"
  end

  test "GET /docs/v2 renders the v2 docs page", %{conn: conn} do
    conn = get(conn, ~p"/docs/v2")
    html = html_response(conn, 200)

    assert html =~ "ServiceRadar V2 documentation"
    assert html =~ "Go SDK"
    assert html =~ "Rust SDK"
    assert html =~ "Dashboard SDK"
    refute html =~ "export const mountDashboard = mountReactDashboard"
  end

  test "GET /docs/v2/dashboard-sdk renders the dashboard SDK guide", %{conn: conn} do
    conn = get(conn, ~p"/docs/v2/dashboard-sdk")
    html = html_response(conn, 200)

    assert html =~ "Dashboard SDK"
    assert html =~ "@serviceradar/dashboard-sdk"
    assert html =~ ~s(class="not-prose docs-code-window mockup-code" data-language="JSX")
    assert html =~ "mountDashboard"
    assert html =~ "mountReactDashboard"
  end

  test "GET /docs/v1/dashboard-sdk redirects to the v2 dashboard SDK guide", %{conn: conn} do
    conn = get(conn, ~p"/docs/v1/dashboard-sdk")

    assert redirected_to(conn) == "/docs/v2/dashboard-sdk"
  end

  test "GET /docs/v1/api redirects to the v2 api reference", %{conn: conn} do
    conn = get(conn, ~p"/docs/v1/api")

    assert redirected_to(conn) == "/docs/v2/api"
  end

  test "GET /docs/v2/api renders the cached API reference", %{conn: conn} do
    conn = get(conn, ~p"/docs/v2/api")
    html = html_response(conn, 200)

    assert html =~ "ServiceRadar API Reference"
    assert html =~ "Portal Raw JSON"
    assert html =~ "/api/v2/devices"
  end

  test "GET /docs/v1/api/openapi.json redirects to the v2 openapi artifact", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get(~p"/docs/v1/api/openapi.json")

    assert redirected_to(conn) == "/docs/v2/api/openapi.json"
  end

  test "GET /docs/v2/api/openapi.json returns the cached OpenAPI artifact", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get(~p"/docs/v2/api/openapi.json")

    body = json_response(conn, 200)

    assert body["openapi"] == "3.0.3"
    assert get_in(body, ["info", "title"]) == "ServiceRadar API"
    assert get_in(body, ["paths", "/api/v2/devices", "get", "summary"]) == "List devices"
  end

  test "GET /contribute renders the contribution guide", %{conn: conn} do
    conn = get(conn, ~p"/contribute")
    html = html_response(conn, 200)

    assert html =~ "Submit a plugin through a reviewed PR"
    assert html =~ "Required package contents"
  end
end
