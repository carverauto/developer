defmodule DeveloperPortal.Registry.ReleaseIndex do
  @moduledoc """
  Reads the published signing indexes that the ServiceRadar release pipeline
  attaches to Forgejo releases.

  The repository tree never contains the signed bundles themselves — the
  signed WASM plugins and native add-ons are published to an OCI registry and
  catalogued in two JSON assets on each release:

    * `serviceradar-wasm-plugin-index.json` — keyed by `plugin_id`
    * `serviceradar-native-addon-index.json` — keyed by `addon_id`

  These files are therefore the source of truth for which artifacts are signed
  and where to pull them. Lookups are best-effort: any failure resolves to an
  empty index so the catalog degrades to "unsigned" rather than crashing the
  refresh.
  """

  require Logger

  @default_wasm_asset "serviceradar-wasm-plugin-index.json"
  @default_addon_asset "serviceradar-native-addon-index.json"
  @default_releases_limit 20

  @type entry_map :: %{optional(String.t()) => map()}
  @type t :: %{wasm: entry_map(), addons: entry_map(), release_tag: String.t() | nil}

  @spec empty() :: t()
  def empty, do: %{wasm: %{}, addons: %{}, release_tag: nil}

  @doc """
  Fetches the latest stable release and returns its plugin/add-on signing
  indexes keyed by id.
  """
  @spec fetch(map()) :: t()
  def fetch(config) do
    case latest_stable_release(config) do
      {:ok, release} ->
        %{
          release_tag: release["tag_name"],
          wasm: load_index(config, release, wasm_asset(config), "plugins", "plugin_id"),
          addons: load_index(config, release, addon_asset(config), "addons", "addon_id")
        }

      {:error, reason} ->
        Logger.warning("release signing index unavailable: #{inspect(reason)}")
        empty()
    end
  end

  defp latest_stable_release(config) do
    url =
      "#{config.api_base_url}/repos/#{config.owner}/#{config.repo}/releases?limit=#{releases_limit(config)}"

    case Req.get(url, config.req_options) do
      {:ok, %Req.Response{status: 200, body: releases}} when is_list(releases) ->
        case Enum.find(releases, &stable_release?/1) do
          nil -> {:error, :no_stable_release}
          release -> {:ok, release}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp stable_release?(release) do
    release["draft"] == false and release["prerelease"] == false
  end

  defp load_index(config, release, asset_name, collection_key, id_key) do
    with %{"browser_download_url" => url} <- find_asset(release, asset_name),
         {:ok, %Req.Response{status: 200, body: body}} <- Req.get(url, config.req_options),
         {:ok, decoded} <- decode_body(body) do
      decoded
      |> Map.get(collection_key, [])
      |> index_by(id_key, asset_name)
    else
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  # Build an id => entry map, skipping entries with a missing/blank id (which
  # would otherwise create an unreachable nil-keyed entry and hide a malformed
  # release asset). Duplicate ids keep the last entry; a warning surfaces both.
  defp index_by(entries, id_key, asset_name) when is_list(entries) do
    Enum.reduce(entries, %{}, fn entry, acc ->
      case entry[id_key] do
        id when is_binary(id) and id != "" ->
          if Map.has_key?(acc, id) do
            Logger.warning("duplicate #{id_key} \"#{id}\" in #{asset_name}; keeping last entry")
          end

          Map.put(acc, id, entry)

        _ ->
          Logger.warning("#{asset_name} entry missing #{id_key}; skipping")
          acc
      end
    end)
  end

  defp index_by(_entries, _id_key, _asset_name), do: %{}

  defp find_asset(release, asset_name) do
    release
    |> Map.get("assets", [])
    |> Enum.find(&(&1["name"] == asset_name))
  end

  defp decode_body(body) when is_map(body), do: {:ok, body}
  defp decode_body(body) when is_binary(body), do: Jason.decode(body)
  defp decode_body(_body), do: :error

  defp wasm_asset(config), do: Map.get(config, :wasm_index_asset) || @default_wasm_asset
  defp addon_asset(config), do: Map.get(config, :addon_index_asset) || @default_addon_asset
  defp releases_limit(config), do: Map.get(config, :releases_limit) || @default_releases_limit
end
