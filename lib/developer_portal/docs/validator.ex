defmodule DeveloperPortal.Docs.Validator do
  @moduledoc false

  @markdown_link_regex ~r/!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/
  @known_site_paths MapSet.new(["/", "/plugins", "/contribute"])

  def validate!(versions) when is_list(versions) do
    versions_by_id = Map.new(versions, &{&1.id, &1})
    ensure_unique_versions!(versions, versions_by_id)

    Enum.each(versions, fn version ->
      ensure_unique_sections!(version)

      Enum.each(version.sections, fn section ->
        ensure_section_version!(section, versions_by_id)
        ensure_internal_links!(section, versions_by_id)
      end)
    end)

    versions
  end

  defp ensure_unique_versions!(versions, versions_by_id) do
    if map_size(versions_by_id) != length(versions) do
      raise ArgumentError, "duplicate docs version ids detected"
    end
  end

  defp ensure_unique_sections!(version) do
    section_ids = Enum.map(version.sections, & &1.id)

    if MapSet.size(MapSet.new(section_ids)) != length(section_ids) do
      raise ArgumentError, "duplicate docs section ids detected for version #{version.id}"
    end
  end

  defp ensure_section_version!(section, versions_by_id) do
    unless Map.has_key?(versions_by_id, section.version) do
      raise ArgumentError,
            "docs section #{section.id} references unknown version #{section.version}"
    end
  end

  defp ensure_internal_links!(section, versions_by_id) do
    section.body
    |> extract_markdown_links()
    |> Enum.each(fn target -> validate_link_target!(target, section, versions_by_id) end)
  end

  defp extract_markdown_links(body) do
    Regex.scan(@markdown_link_regex, body, capture: :all_but_first)
    |> Enum.map(fn [target] -> target end)
  end

  defp validate_link_target!("#" <> _fragment, _section, _versions_by_id), do: :ok
  defp validate_link_target!("mailto:" <> _rest, _section, _versions_by_id), do: :ok
  defp validate_link_target!("tel:" <> _rest, _section, _versions_by_id), do: :ok

  defp validate_link_target!(target, section, versions_by_id) do
    uri = URI.parse(target)

    cond do
      uri.scheme in ["http", "https"] ->
        :ok

      uri.scheme != nil ->
        raise ArgumentError,
              "unsupported docs link scheme in #{section.version}/#{section.id}: #{target}"

      root_path?(uri.path) ->
        validate_root_path!(uri.path, section, versions_by_id)

      true ->
        validate_relative_path!(uri.path || target, section, versions_by_id)
    end
  end

  defp root_path?(path) when is_binary(path), do: String.starts_with?(path, "/")
  defp root_path?(_path), do: false

  defp validate_root_path!(path, section, versions_by_id) do
    cond do
      MapSet.member?(@known_site_paths, path) ->
        :ok

      String.starts_with?(path, "/docs/") ->
        validate_docs_route!(path, section, versions_by_id)

      true ->
        raise ArgumentError, "unknown site path in #{section.version}/#{section.id}: #{path}"
    end
  end

  defp validate_relative_path!(path, section, versions_by_id) do
    normalized =
      path
      |> String.trim()
      |> String.trim_leading("./")
      |> String.trim_trailing(".md")

    case get_in(versions_by_id, [section.version, Access.key!(:sections)]) do
      sections when is_list(sections) ->
        if Enum.any?(sections, &(&1.id == normalized)) do
          :ok
        else
          raise ArgumentError,
                "broken docs link in #{section.version}/#{section.id}: #{path}"
        end
    end
  end

  defp validate_docs_route!(path, section, versions_by_id) do
    case String.split(path, "/", trim: true) do
      ["docs", version] ->
        ensure_known_version!(version, section, versions_by_id)

      ["docs", version, target_section] ->
        ensure_known_section!(version, target_section, section, versions_by_id)

      _ ->
        raise ArgumentError, "invalid docs route in #{section.version}/#{section.id}: #{path}"
    end
  end

  defp ensure_known_version!(version, section, versions_by_id) do
    unless Map.has_key?(versions_by_id, version) do
      raise ArgumentError,
            "broken docs link in #{section.version}/#{section.id}: /docs/#{version}"
    end
  end

  defp ensure_known_section!(version, target_section, section, versions_by_id) do
    ensure_known_version!(version, section, versions_by_id)

    if Enum.any?(versions_by_id[version].sections, &(&1.id == target_section)) do
      :ok
    else
      raise ArgumentError,
            "broken docs link in #{section.version}/#{section.id}: /docs/#{version}/#{target_section}"
    end
  end
end
