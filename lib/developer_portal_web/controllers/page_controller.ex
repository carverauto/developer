defmodule DeveloperPortalWeb.PageController do
  use DeveloperPortalWeb, :controller

  alias DeveloperPortal.ApiDocs
  alias DeveloperPortal.Docs

  def home(conn, _params) do
    render(conn, :home,
      versions: Docs.versions(),
      featured_plugins: DeveloperPortal.Registry.featured_plugins()
    )
  end

  def docs_index(conn, _params) do
    conn
    |> redirect(to: ~p"/docs/v1")
  end

  def docs(conn, %{"version" => version}) do
    case Docs.version(version) do
      nil ->
        send_resp(conn, :not_found, "Documentation version not found")

      docs_version ->
        render(conn, :docs,
          docs_version: docs_version,
          versions: Docs.versions()
        )
    end
  end

  def api_docs(conn, %{"version" => version}) do
    case Docs.version(version) do
      nil ->
        send_resp(conn, :not_found, "Documentation version not found")

      docs_version ->
        render(conn, :api_docs,
          docs_version: docs_version,
          versions: Docs.versions(),
          api_document: ApiDocs.document(version),
          api_source: ApiDocs.version_source(version)
        )
    end
  end

  def api_openapi(conn, %{"version" => version}) do
    case ApiDocs.raw_spec(version) do
      nil ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "api_docs_unavailable", message: "OpenAPI document is not cached yet"})

      spec ->
        json(conn, spec)
    end
  end

  def contribute(conn, _params) do
    render(conn, :contribute)
  end
end
