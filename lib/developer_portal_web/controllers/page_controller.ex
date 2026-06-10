defmodule DeveloperPortalWeb.PageController do
  use DeveloperPortalWeb, :controller

  alias DeveloperPortal.ApiDocs
  alias DeveloperPortal.Docs

  def home(conn, _params) do
    render(conn, :home,
      versions: Docs.versions(),
      featured_plugins: DeveloperPortal.Registry.featured_plugins(),
      featured_addons: DeveloperPortal.Registry.featured_addons()
    )
  end

  def docs_index(conn, _params) do
    conn
    |> redirect(to: ~p"/docs/v2")
  end

  def docs(conn, %{"version" => version}) do
    case normalize_docs_version(version) do
      {:redirect, target} ->
        redirect(conn, to: ~p"/docs/#{target}")

      normalized_version ->
        case Docs.version(normalized_version) do
          nil ->
            send_resp(conn, :not_found, "Documentation version not found")

          docs_version ->
            render(conn, :docs,
              docs_version: docs_version,
              versions: Docs.versions()
            )
        end
    end
  end

  def docs_section(conn, %{"version" => version, "section" => section}) do
    case normalize_docs_version(version) do
      {:redirect, target} ->
        redirect(conn, to: ~p"/docs/#{target}/#{section}")

      normalized_version ->
        with docs_version when not is_nil(docs_version) <- Docs.version(normalized_version),
             docs_section when not is_nil(docs_section) <-
               Docs.section(normalized_version, section) do
          render(conn, :docs_section,
            docs_version: docs_version,
            docs_section: docs_section,
            versions: Docs.versions()
          )
        else
          _ -> send_resp(conn, :not_found, "Documentation section not found")
        end
    end
  end

  def api_docs(conn, %{"version" => version}) do
    case normalize_docs_version(version) do
      {:redirect, target} ->
        redirect(conn, to: ~p"/docs/#{target}/api")

      normalized_version ->
        case Docs.version(normalized_version) do
          nil ->
            send_resp(conn, :not_found, "Documentation version not found")

          docs_version ->
            render(conn, :api_docs,
              docs_version: docs_version,
              versions: Docs.versions(),
              api_document: ApiDocs.document(normalized_version),
              api_source: ApiDocs.version_source(normalized_version)
            )
        end
    end
  end

  def api_openapi(conn, %{"version" => version}) do
    case normalize_docs_version(version) do
      {:redirect, target} ->
        redirect(conn, to: ~p"/docs/#{target}/api/openapi.json")

      normalized_version ->
        case ApiDocs.raw_spec(normalized_version) do
          nil ->
            conn
            |> put_status(:service_unavailable)
            |> json(%{
              error: "api_docs_unavailable",
              message: "OpenAPI document is not cached yet"
            })

          spec ->
            json(conn, spec)
        end
    end
  end

  def contribute(conn, _params) do
    render(conn, :contribute)
  end

  defp normalize_docs_version("v1"), do: {:redirect, "v2"}
  defp normalize_docs_version(version), do: version
end
