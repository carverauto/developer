defmodule DeveloperPortalWeb.PageController do
  use DeveloperPortalWeb, :controller

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

  def contribute(conn, _params) do
    render(conn, :contribute)
  end
end
