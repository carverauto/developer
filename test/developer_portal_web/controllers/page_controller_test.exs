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

  test "GET /docs/v1/api renders the cached API reference", %{conn: conn} do
    conn = get(conn, ~p"/docs/v1/api")
    html = html_response(conn, 200)

    assert html =~ "ServiceRadar API Reference"
    assert html =~ "Portal Raw JSON"
    assert html =~ "/api/v2/devices"
  end

  test "GET /docs/v1/api/openapi.json returns the cached OpenAPI artifact", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get(~p"/docs/v1/api/openapi.json")

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
