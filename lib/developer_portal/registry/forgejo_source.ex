defmodule DeveloperPortal.Registry.ForgejoSource do
  @moduledoc false

  @behaviour DeveloperPortal.Registry.Source

  require Logger

  alias DeveloperPortal.Registry.Addon
  alias DeveloperPortal.Registry.Plugin
  alias DeveloperPortal.Registry.PublicURL
  alias DeveloperPortal.Registry.ReleaseIndex
  alias DeveloperPortal.Registry.Validator

  @manifest_files [
    %{name: "plugin.yaml", kind: "check"},
    %{name: "plugin.console.yaml", kind: "console"},
    %{name: "plugin.inventory_sync.yaml", kind: "inventory_sync"},
    %{name: "plugin.stream.yaml", kind: "stream"},
    %{name: "manifest.json", kind: "check"},
    %{name: "manifest.console.json", kind: "console"},
    %{name: "manifest.inventory_sync.json", kind: "inventory_sync"},
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
      index = ReleaseIndex.fetch(config).wasm

      plugins =
        entries
        |> Enum.filter(&(&1["type"] == "dir"))
        |> Enum.flat_map(&fetch_directory_plugins(config, &1, index))
        |> Enum.sort_by(&{if(&1.official, do: 0, else: 1), &1.name})
        |> Validator.validate!()

      {:ok, plugins}
    end
  end

  defp fetch_directory_plugins(config, entry, index) do
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
                build_plugin(config, manifest_entry, manifest.kind, language, index, %{
                  source_url: source_url,
                  readme_url: readme_url,
                  directory: directory,
                  dist: dist
                })
              ]
          end
        end)

      {:error, reason} ->
        raise "failed to fetch plugin directory #{entry["path"]}: #{inspect(reason)}"
    end
  rescue
    error ->
      Logger.warning("skipping plugin directory #{entry["path"]}: #{inspect(error)}")
      []
  end

  defp build_plugin(config, manifest_entry, kind, language, index, urls) do
    manifest = fetch_manifest!(config, manifest_entry)
    slug = fetch_id!(manifest)
    release = Map.get(index, slug)
    signed = release_signed?(release)
    # OCI metadata is only meaningful for a signed, published artifact. Gating it
    # on `signed` keeps the "oci_ref implies signed" invariant the Validator
    # enforces, so a future index entry that lists an OCI ref without a signature
    # can never crash the whole refresh.
    published = if signed, do: release, else: nil
    %{source_url: source_url, readme_url: readme_url, directory: directory, dist: dist} = urls

    %Plugin{
      slug: slug,
      name: fetch_string!(manifest, "name"),
      author: config.default_author,
      version: fetch_string!(manifest, "version"),
      summary: fetch_string!(manifest, "description"),
      description: fetch_string!(manifest, "description"),
      type: config.default_type,
      official: config.default_type == "official",
      language: language,
      category: categorize_plugin(manifest, kind),
      signed: signed,
      source_url: PublicURL.githubize(source_url),
      readme_url: PublicURL.githubize(readme_url),
      manifest_url: PublicURL.githubize(download_url(manifest_entry)),
      config_schema_url: PublicURL.githubize(config_schema_url(kind, directory, dist)),
      wasm_url: PublicURL.githubize(find_download_url(dist, @wasm_candidates)),
      artifact_url: PublicURL.githubize(find_download_url(dist, @checksum_candidates)),
      signature_url: PublicURL.githubize(find_download_url(dist, @signature_candidates)),
      oci_ref: published && published["oci_ref"],
      oci_digest: published && published["oci_digest"],
      signature_digest: published && published["upload_signature_digest"],
      bundle_digest: published && published["bundle_digest"],
      installation: installation_text(kind, published),
      runtime: fetch_optional_string(manifest, "runtime"),
      entrypoint: fetch_optional_string(manifest, "entrypoint"),
      outputs: fetch_optional_string(manifest, "outputs"),
      capabilities: fetch_string_list(manifest, "capabilities"),
      allowed_domains: get_in(manifest, ["permissions", "allowed_domains"]) |> string_list(),
      allowed_ports: get_in(manifest, ["permissions", "allowed_ports"]) |> integer_list(),
      sample_kind: kind
    }
  end

  @impl true
  def fetch_addons(opts) do
    with {:ok, config} <- build_config(opts),
         {:ok, entries} <- list_directory(config, config.addon_root) do
      index = ReleaseIndex.fetch(config).addons

      addons =
        entries
        |> Enum.filter(&(&1["type"] == "dir"))
        |> Enum.flat_map(&fetch_directory_addon(config, &1, index))
        |> Enum.sort_by(& &1.name)
        |> Validator.validate_addons!()

      {:ok, addons}
    end
  end

  # Maps an add-on id to its developer-portal reference doc slug.
  @addon_docs %{
    "sample" => "addon-sample",
    "rust-sample" => "addon-rust-sample",
    "powerdns" => "addon-powerdns",
    "netprobe" => "addon-netprobe",
    "workload-identity" => "addon-workload-identity",
    "endpoint-inventory" => "addon-endpoint-inventory",
    "bumblebee" => "addon-bumblebee-scan",
    "rdp" => "addon-rdp-adapter"
  }

  defp fetch_directory_addon(config, entry, index) do
    case list_directory(config, entry["path"]) do
      {:ok, files} ->
        directory = index_entries(files)

        with manifest_entry when not is_nil(manifest_entry) <-
               directory["addon.yaml"] || directory["addon.yml"],
             manifest <- fetch_manifest!(config, manifest_entry),
             id when is_binary(id) <- fetch_optional_string(manifest, "id"),
             release when not is_nil(release) <- Map.get(index, id) do
          [build_addon(entry, directory, manifest, id, release)]
        else
          _ -> []
        end

      {:error, reason} ->
        raise "failed to fetch addon directory #{entry["path"]}: #{inspect(reason)}"
    end
  rescue
    error ->
      Logger.warning("skipping addon directory #{entry["path"]}: #{inspect(error)}")
      []
  end

  defp build_addon(entry, directory, manifest, id, release) do
    artifacts = release |> Map.get("artifacts", []) |> Enum.map(&normalize_artifact/1)
    signed = addon_signed?(artifacts)
    # OCI metadata is only exposed for a fully-signed add-on, keeping the
    # "oci_ref implies signed" invariant the Validator enforces.
    published = if signed, do: release, else: nil
    description = fetch_optional_string(manifest, "description") || release["name"]

    %Addon{
      slug: id,
      name: fetch_optional_string(manifest, "name") || release["name"],
      summary: description,
      description: description,
      version: to_string(release["version"] || fetch_optional_string(manifest, "version")),
      language: humanize_language(fetch_optional_string(manifest, "language")),
      kind: fetch_optional_string(manifest, "kind") || "native",
      delivery: fetch_optional_string(manifest, "delivery"),
      supervision: fetch_optional_string(manifest, "supervision"),
      capabilities: fetch_string_list(manifest, "capabilities"),
      platforms: get_in(manifest, ["requires", "platforms"]) |> string_list(),
      architectures: Enum.map(artifacts, &"#{&1.os}/#{&1.arch}"),
      artifacts: artifacts,
      signed: signed,
      oci_ref: published && published["oci_ref"],
      oci_digest: published && published["oci_digest"],
      bundle_digest: published && published["bundle_digest"],
      source_url: PublicURL.githubize(entry["html_url"]),
      readme_url: PublicURL.githubize(html_or_download_url(directory["README.md"])),
      docs_path: "/docs/v2/" <> Map.get(@addon_docs, id, "addons"),
      official: true
    }
  end

  defp normalize_artifact(artifact) do
    %{
      os: to_string(artifact["os"]),
      arch: to_string(artifact["arch"]),
      signature_digest: artifact["signature_digest"],
      sha256: artifact["sha256"]
    }
  end

  defp addon_signed?([]), do: false

  defp addon_signed?(artifacts) do
    Enum.all?(artifacts, fn artifact ->
      is_binary(artifact.signature_digest) and artifact.signature_digest != ""
    end)
  end

  defp humanize_language("go"), do: "Go"
  defp humanize_language("rust"), do: "Rust"
  defp humanize_language(language) when is_binary(language) and language != "", do: language
  defp humanize_language(_language), do: "Unknown"

  defp build_config(opts) do
    merged =
      Application.get_env(:developer_portal, DeveloperPortal.Registry, [])
      |> Keyword.get(:source_opts, [])
      |> Keyword.merge(opts)

    {:ok,
     %{
       api_base_url: Keyword.fetch!(merged, :api_base_url),
       content_base_url: Keyword.get(merged, :content_base_url),
       owner: Keyword.fetch!(merged, :owner),
       repo: Keyword.fetch!(merged, :repo),
       ref: Keyword.fetch!(merged, :ref),
       plugin_root: Keyword.fetch!(merged, :plugin_root),
       addon_root: Keyword.get(merged, :addon_root, "addons"),
       default_author: Keyword.get(merged, :default_author, "ServiceRadar"),
       default_type: Keyword.get(merged, :default_type, "official"),
       wasm_index_asset: Keyword.get(merged, :wasm_index_asset),
       addon_index_asset: Keyword.get(merged, :addon_index_asset),
       releases_limit: Keyword.get(merged, :releases_limit),
       req_options: merge_req_options(Keyword.get(merged, :req_options, []))
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

  defp fetch_manifest!(config, entry) do
    body = fetch_raw_body!(config, download_url(entry))

    case Path.extname(entry["name"]) do
      ".json" -> Jason.decode!(body)
      ".yaml" -> YamlElixir.read_from_string!(body)
      ".yml" -> YamlElixir.read_from_string!(body)
    end
  end

  defp fetch_raw_body!(config, url) do
    case Req.get(request_url(config, url), config.req_options) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        body

      {:ok, %Req.Response{status: status, body: body}} ->
        raise "unexpected status #{status}: #{inspect(body)}"

      {:error, reason} ->
        raise "request failed for #{url}: #{inspect(reason)}"
    end
  end

  defp request_url(%{content_base_url: nil}, url), do: url

  defp request_url(%{content_base_url: content_base_url}, url) do
    content_uri = URI.parse(content_base_url)
    request_uri = URI.parse(url)

    request_uri
    |> Map.put(:scheme, content_uri.scheme)
    |> Map.put(:host, content_uri.host)
    |> Map.put(:port, content_uri.port)
    |> URI.to_string()
  end

  defp config_schema_url(kind, directory, dist) do
    kind
    |> schema_candidates()
    |> Enum.find_value(fn name ->
      find_download_url(dist, [name]) || find_download_url(directory, [name])
    end)
  end

  defp schema_candidates("stream"), do: ["config.stream.schema.json"]
  defp schema_candidates("console"), do: ["config.console.schema.json", "config.schema.json"]

  defp schema_candidates("inventory_sync"),
    do: ["config.inventory_sync.schema.json", "config.schema.json"]

  defp schema_candidates(_kind), do: ["config.schema.json"]

  defp categorize_plugin(manifest, "stream") do
    outputs = fetch_optional_string(manifest, "outputs") || ""

    if String.contains?(outputs, "camera_stream"), do: "streaming", else: "streaming"
  end

  defp categorize_plugin(_manifest, "console"), do: "remote access"
  defp categorize_plugin(_manifest, "inventory_sync"), do: "automation"

  defp categorize_plugin(manifest, _kind) do
    outputs = fetch_optional_string(manifest, "outputs") || ""

    cond do
      String.contains?(outputs, "proxmox_console") -> "remote access"
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

  defp release_signed?(nil), do: false

  defp release_signed?(release) when is_map(release) do
    case release["upload_signature_digest"] do
      digest when is_binary(digest) and digest != "" -> true
      _ -> false
    end
  end

  defp installation_text(kind, nil) do
    package = if kind == "stream", do: "streaming", else: "standard"

    "Review the #{package} manifest on GitHub; the signed bundle will be published to the ServiceRadar registry on the next release."
  end

  defp installation_text(_kind, release) when is_map(release) do
    case release["oci_ref"] do
      ref when is_binary(ref) and ref != "" ->
        "Pull the signed `#{ref}` bundle from the ServiceRadar registry, then assign it to an agent from the control plane."

      _ ->
        "Pull the signed bundle from the ServiceRadar registry, then assign it to an agent from the control plane."
    end
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

  defp merge_req_options(req_options) do
    headers =
      (Keyword.get(req_options, :headers, []) ++ github_headers())
      |> Enum.uniq_by(fn {name, _value} -> String.downcase(to_string(name)) end)

    Keyword.put(req_options, :headers, headers)
  end

  defp github_headers do
    user_agent = [{"user-agent", "serviceradar-developer-portal"}]

    case System.get_env("GITHUB_TOKEN") || System.get_env("GH_TOKEN") do
      token when is_binary(token) and token != "" ->
        [{"authorization", "Bearer #{token}"} | user_agent]

      _ ->
        user_agent
    end
  end
end
