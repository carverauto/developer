defmodule DeveloperPortal.Docs do
  @moduledoc """
  Repository-backed documentation metadata loaded from markdown and YAML files.
  """

  alias DeveloperPortal.Docs.Section
  alias DeveloperPortal.Docs.Version

  @content_root Path.expand("../../priv/content/docs", __DIR__)
  @versions_path Path.join(@content_root, "versions.yaml")
  @section_paths Path.wildcard(Path.join(@content_root, "*/*.md"))

  for path <- [@versions_path | @section_paths] do
    @external_resource path
  end

  def versions do
    Enum.map(all(), &Map.take(&1, [:id, :label]))
  end

  def version(id) do
    Enum.find(all(), &(&1.id == id))
  end

  def all do
    build_versions(@versions_path, @section_paths)
  end

  defp build_versions(versions_path, section_paths) do
    versions =
      versions_path
      |> YamlElixir.read_from_file!()
      |> Enum.map(fn attrs ->
        attrs
        |> normalize_map_keys()
        |> then(fn version ->
          %Version{
            id: fetch_string!(version, "id"),
            label: fetch_string!(version, "label"),
            title: fetch_string!(version, "title"),
            summary: fetch_string!(version, "summary"),
            sections: []
          }
        end)
      end)

    sections_by_version =
      section_paths
      |> Enum.map(&build_section/1)
      |> Enum.group_by(& &1.version)

    Enum.map(versions, fn version ->
      %{
        version
        | sections: Map.get(sections_by_version, version.id, []) |> Enum.sort_by(& &1.order)
      }
    end)
  end

  defp build_section(path) do
    version = path |> Path.dirname() |> Path.basename()
    id = path |> Path.basename(".md")

    {frontmatter, body} = parse_markdown_file!(path)
    attrs = normalize_map_keys(frontmatter)

    %Section{
      id: id,
      version: version,
      title: fetch_string!(attrs, "title"),
      audience: fetch_string!(attrs, "audience"),
      description: fetch_string!(attrs, "description"),
      order: fetch_integer!(attrs, "order"),
      body: body,
      html: markdown_to_html(body)
    }
  end

  defp parse_markdown_file!(path) do
    case File.read!(path) do
      <<"---\n", rest::binary>> ->
        [frontmatter, body] = String.split(rest, "\n---\n", parts: 2)
        {YamlElixir.read_from_string!(frontmatter), String.trim(body)}

      _ ->
        raise ArgumentError, "expected markdown file with YAML front matter: #{path}"
    end
  end

  defp markdown_to_html(markdown) do
    markdown
    |> Earmark.as_html!()
    |> Phoenix.HTML.raw()
  end

  defp normalize_map_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp fetch_string!(attrs, key) do
    attrs
    |> Map.fetch!(key)
    |> to_string()
  end

  defp fetch_integer!(attrs, key) do
    attrs
    |> Map.fetch!(key)
    |> then(fn
      value when is_integer(value) -> value
      value when is_binary(value) -> String.to_integer(value)
    end)
  end
end
