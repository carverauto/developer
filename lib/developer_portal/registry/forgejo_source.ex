defmodule DeveloperPortal.Registry.ForgejoSource do
  @moduledoc false

  @behaviour DeveloperPortal.Registry.Source

  alias DeveloperPortal.Registry.Plugin

  @manifest_files [
    %{name: "plugin.yaml", kind: "check"},
    %{name: "plugin.stream.yaml", kind: "stream"},
    %{name: "manifest.json", kind: "check"},
    %{name: "manifest.stream.json", kind: "stream"}
  ]

  @wasm_candidates ["plugin.wasm"]
  @signature_candidates [
    "plugin.wasm.sig",
    "plugin.wasm.minisig",
    "plugin.wasm.bundle",
    "plugin.wasm.cosign"
  ]
  @checksum_candidates ["plugin.wasm.sha256", "checksums.txt", "sha256sum.txt"]

  @impl true
  def fetch_plugins(opts) do
    with {:ok, config} <- build_config(opts),
         {:ok, entries} <- list_directory(config, config.plugin_root) do
      plugins =
        entries
        |> Enum.filter(&(&1["type"] == "dir"))
        |> Enum.flat_map(&fetch_directory_plugins(config, &1))
        |> Enum.sort_by(&{if(&1.official, do: 0, else: 1), &1.name})

      {:ok, plugins}
    end
  end

  defp fetch_directory_plugins(config, entry) do
    case list_directory(config, entry["path"]) do
      {:ok, root_entries} ->
        directory = index_entries(root_entries)
        dist = root_entries |> dist_entries(config) |> index_entries()
        language = detect_language(directory)
        source_url = entry["html_url"]
        readme_url = html_or_download_url(directory["README.md"])

        Enum.flat_map(@manifest_files, fn manifest ->
          case directory[manifest.name] do
            nil ->
              []

            manifest_entry ->
              [
                build_plugin(
                  config,
                  manifest_entry,
                  manifest.kind,
                  source_url,
                  readme_url,
                  directory,
                  dist,
                  language
                )
              ]
          end
        end)

      {:error, reason} ->
        raise "failed to fetch plugin directory #{entry["path"]}: #{inspect(reason)}"
    end
  rescue
    _error ->
      []
  end

  defp build_plugin(
         config,
         manifest_entry,
         kind,
         source_url,
         readme_url,
         directory,
         dist,
         language
       ) do
    manifest = fetch_manifest!(manifest_entry)
    signature_url = find_download_url(dist, @signature_candidates)
    checksum_url = find_download_url(dist, @checksum_candidates)
    wasm_url = find_download_url(dist, @wasm_candidates)

    %Plugin{
      slug: fetch_id!(manifest),
      name: fetch_string!(manifest, "name"),
      author: config.default_author,
      version: fetch_string!(manifest, "version"),
      summary: fetch_string!(manifest, "description"),
      description: fetch_string!(manifest, "description"),
      type: config.default_type,
      official: config.default_type == "official",
      language: language,
      category: categorize_plugin(manifest, kind),
      signed: not is_nil(signature_url),
      source_url: source_url,
      readme_url: readme_url,
      manifest_url: download_url(manifest_entry),
      config_schema_url: config_schema_url(kind, directory, dist),
      wasm_url: wasm_url,
      artifact_url: checksum_url,
      signature_url: signature_url,
      installation: installation_text(kind, wasm_url),
      runtime: fetch_optional_string(manifest, "runtime"),
      entrypoint: fetch_optional_string(manifest, "entrypoint"),
      outputs: fetch_optional_string(manifest, "outputs"),
      capabilities: fetch_string_list(manifest, "capabilities"),
      allowed_domains: get_in(manifest, ["permissions", "allowed_domains"]) |> string_list(),
      allowed_ports: get_in(manifest, ["permissions", "allowed_ports"]) |> integer_list(),
      sample_kind: kind
    }
  end

  defp build_config(opts) do
    merged =
      Application.get_env(:developer_portal, DeveloperPortal.Registry, [])
      |> Keyword.get(:source_opts, [])
      |> Keyword.merge(opts)

    {:ok,
     %{
       api_base_url: Keyword.fetch!(merged, :api_base_url),
       owner: Keyword.fetch!(merged, :owner),
       repo: Keyword.fetch!(merged, :repo),
       ref: Keyword.fetch!(merged, :ref),
       plugin_root: Keyword.fetch!(merged, :plugin_root),
       default_author: Keyword.get(merged, :default_author, "ServiceRadar"),
       default_type: Keyword.get(merged, :default_type, "official"),
       req_options: Keyword.get(merged, :req_options, [])
     }}
  rescue
    error in KeyError -> {:error, error}
  end

  defp list_directory(config, path) do
    url =
      "#{config.api_base_url}/repos/#{config.owner}/#{config.repo}/contents/#{path}?ref=#{config.ref}"

    case Req.get(url, config.req_options) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp list_directory!(config, path) do
    case list_directory(config, path) do
      {:ok, entries} -> entries
      {:error, reason} -> raise "failed to fetch directory #{path}: #{inspect(reason)}"
    end
  end

  defp dist_entries(root_entries, config) do
    case Enum.find(root_entries, &(&1["type"] == "dir" and &1["name"] == "dist")) do
      nil -> []
      dist_entry -> list_directory!(config, dist_entry["path"])
    end
  end

  defp fetch_manifest!(entry) do
    body = fetch_raw_body!(download_url(entry))

    case Path.extname(entry["name"]) do
      ".json" -> Jason.decode!(body)
      ".yaml" -> YamlElixir.read_from_string!(body)
      ".yml" -> YamlElixir.read_from_string!(body)
    end
  end

  defp fetch_raw_body!(url) do
    case Req.get(url) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        body

      {:ok, %Req.Response{status: status, body: body}} ->
        raise "unexpected status #{status}: #{inspect(body)}"

      {:error, reason} ->
        raise "request failed for #{url}: #{inspect(reason)}"
    end
  end

  defp config_schema_url(kind, directory, dist) do
    kind
    |> schema_candidates()
    |> Enum.find_value(fn name ->
      find_download_url(dist, [name]) || find_download_url(directory, [name])
    end)
  end

  defp schema_candidates("stream"), do: ["config.stream.schema.json"]
  defp schema_candidates(_kind), do: ["config.schema.json"]

  defp categorize_plugin(manifest, "stream") do
    outputs = fetch_optional_string(manifest, "outputs") || ""

    if String.contains?(outputs, "camera_stream"), do: "streaming", else: "streaming"
  end

  defp categorize_plugin(manifest, _kind) do
    outputs = fetch_optional_string(manifest, "outputs") || ""

    cond do
      String.contains?(outputs, "camera_stream") -> "streaming"
      String.contains?(outputs, "plugin_result") -> "monitoring"
      true -> "integration"
    end
  end

  defp detect_language(entries) do
    cond do
      Map.has_key?(entries, "go.mod") -> "Go"
      Map.has_key?(entries, "Cargo.toml") -> "Rust"
      true -> "Unknown"
    end
  end

  defp installation_text(kind, nil) do
    package = if kind == "stream", do: "streaming", else: "standard"

    "Review the #{package} manifest in Forgejo and import the published package once the signed WASM artifact is available."
  end

  defp installation_text(kind, _wasm_url) do
    package = if kind == "stream", do: "streaming", else: "standard"

    "Download the #{package} manifest, config schema, and signed WASM artifact from Forgejo, then import them into ServiceRadar."
  end

  defp index_entries(entries) do
    Map.new(entries, fn entry -> {entry["name"], entry} end)
  end

  defp find_download_url(entries, candidates) do
    Enum.find_value(candidates, fn name ->
      entries
      |> Map.get(name)
      |> download_url()
    end)
  end

  defp download_url(nil), do: nil
  defp download_url(entry), do: entry["download_url"] || entry["html_url"]

  defp html_or_download_url(nil), do: nil
  defp html_or_download_url(entry), do: entry["html_url"] || entry["download_url"]

  defp fetch_id!(manifest) do
    fetch_optional_string(manifest, "id") ||
      fetch_optional_string(manifest, "plugin_id") ||
      raise KeyError, key: "id"
  end

  defp fetch_string!(attrs, key) do
    attrs
    |> Map.fetch!(key)
    |> to_string()
  end

  defp fetch_optional_string(attrs, key) do
    case Map.get(attrs, key) do
      nil -> nil
      "" -> nil
      value -> to_string(value)
    end
  end

  defp fetch_string_list(attrs, key) do
    attrs
    |> Map.get(key, [])
    |> string_list()
  end

  defp string_list(values) when is_list(values), do: Enum.map(values, &to_string/1)
  defp string_list(_values), do: []

  defp integer_list(values) when is_list(values) do
    Enum.map(values, fn
      value when is_integer(value) -> value
      value when is_binary(value) -> String.to_integer(value)
    end)
  end

  defp integer_list(_values), do: []
end
