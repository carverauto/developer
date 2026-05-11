defmodule DeveloperPortal.Registry.Validator do
  @moduledoc false

  alias DeveloperPortal.Registry.Plugin

  @valid_types MapSet.new(["official", "community"])
  @valid_kinds MapSet.new(["check", "console", "inventory_sync", "stream"])

  def validate!(plugins) when is_list(plugins) do
    slugs = Enum.map(plugins, & &1.slug)

    if MapSet.size(MapSet.new(slugs)) != length(slugs) do
      raise ArgumentError, "duplicate plugin slugs detected"
    end

    Enum.each(plugins, &validate_plugin!/1)
    plugins
  end

  def validate_plugin!(%Plugin{} = plugin) do
    ensure_non_empty!(plugin.slug, :slug)
    ensure_non_empty!(plugin.name, :name)
    ensure_non_empty!(plugin.author, :author)
    ensure_non_empty!(plugin.version, :version)
    ensure_non_empty!(plugin.summary, :summary)
    ensure_non_empty!(plugin.description, :description)
    ensure_non_empty!(plugin.language, :language)
    ensure_non_empty!(plugin.category, :category)
    ensure_membership!(plugin.type, :type, @valid_types)
    ensure_membership!(plugin.sample_kind, :sample_kind, @valid_kinds)
    ensure_boolean_consistency!(plugin)
    ensure_url!(plugin.source_url, :source_url)
    ensure_optional_url!(plugin.readme_url, :readme_url)
    ensure_url!(plugin.manifest_url, :manifest_url)
    ensure_optional_url!(plugin.config_schema_url, :config_schema_url)
    ensure_signature_metadata!(plugin)
    plugin
  end

  defp ensure_boolean_consistency!(plugin) do
    official_type? = plugin.type == "official"

    if plugin.official != official_type? do
      raise ArgumentError,
            "plugin #{plugin.slug} has inconsistent official flag for type #{plugin.type}"
    end
  end

  defp ensure_signature_metadata!(plugin) do
    ensure_optional_url!(plugin.wasm_url, :wasm_url)
    ensure_optional_url!(plugin.artifact_url, :artifact_url)
    ensure_optional_url!(plugin.signature_url, :signature_url)
    ensure_signed_field!(plugin, :wasm_url)
    ensure_signed_field!(plugin, :signature_url)
    ensure_signed_field!(plugin, :artifact_url)
    ensure_unsigned_has_no_signature!(plugin)
    ensure_signature_has_wasm!(plugin)
  end

  defp ensure_signed_field!(%Plugin{signed: true} = plugin, field) do
    if is_nil(Map.fetch!(plugin, field)) do
      raise ArgumentError, "plugin #{plugin.slug} is signed but is missing #{field}"
    end
  end

  defp ensure_signed_field!(_plugin, _field), do: :ok

  defp ensure_unsigned_has_no_signature!(
         %Plugin{signed: false, signature_url: signature_url} = plugin
       )
       when not is_nil(signature_url) do
    raise ArgumentError,
          "plugin #{plugin.slug} exposes signature_url but is not marked signed"
  end

  defp ensure_unsigned_has_no_signature!(_plugin), do: :ok

  defp ensure_signature_has_wasm!(%Plugin{signature_url: signature_url, wasm_url: nil} = plugin)
       when not is_nil(signature_url) do
    raise ArgumentError,
          "plugin #{plugin.slug} exposes signature metadata without a wasm_url"
  end

  defp ensure_signature_has_wasm!(_plugin), do: :ok

  defp ensure_non_empty!(value, field) when is_binary(value) do
    if String.trim(value) == "" do
      raise ArgumentError, "plugin field #{field} must not be empty"
    end
  end

  defp ensure_non_empty!(value, field) do
    raise ArgumentError,
          "plugin field #{field} must be a non-empty string, got: #{inspect(value)}"
  end

  defp ensure_membership!(value, field, allowed) do
    unless is_binary(value) and MapSet.member?(allowed, value) do
      raise ArgumentError,
            "plugin field #{field} must be one of #{Enum.join(MapSet.to_list(allowed), ", ")}"
    end
  end

  defp ensure_url!(value, field) do
    ensure_optional_url!(value, field)

    if is_nil(value) do
      raise ArgumentError, "plugin field #{field} must be present"
    end
  end

  defp ensure_optional_url!(nil, _field), do: :ok

  defp ensure_optional_url!(value, field) when is_binary(value) do
    uri = URI.parse(value)

    unless uri.scheme in ["http", "https"] and is_binary(uri.host) do
      raise ArgumentError, "plugin field #{field} must be an absolute http(s) URL"
    end
  end

  defp ensure_optional_url!(value, field) do
    raise ArgumentError, "plugin field #{field} must be a URL string, got: #{inspect(value)}"
  end
end
