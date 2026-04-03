defmodule DeveloperPortal.ApiDocs do
  @moduledoc """
  Cached ServiceRadar OpenAPI documents used by the developer portal.
  """

  alias DeveloperPortal.ApiDocs.Store

  def documents do
    Store.documents()
  end

  def versions do
    version_sources()
    |> Enum.map(fn {id, attrs} -> %{id: id, label: Map.fetch!(attrs, "label")} end)
    |> Enum.sort_by(& &1.id)
  end

  def document(version) do
    Store.document(version)
  end

  def raw_spec(version) do
    case document(version) do
      %{raw_spec: raw_spec} -> raw_spec
      _ -> nil
    end
  end

  def version_source(version) do
    version_sources()
    |> Map.get(version)
  end

  def refresh! do
    Store.refresh!()
  end

  def version_sources do
    config = Application.get_env(:developer_portal, __MODULE__, [])
    source = Keyword.get(config, :source, DeveloperPortal.ApiDocs.ServiceRadarSource)
    source_opts = Keyword.get(config, :source_opts, [])

    if function_exported?(source, :version_sources, 1) do
      source.version_sources(source_opts)
    else
      %{}
    end
  end
end
