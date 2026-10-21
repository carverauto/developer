defmodule DeveloperPortal.Registry.ForgejoSourceTest do
  use ExUnit.Case, async: true

  alias DeveloperPortal.Registry.ForgejoSource

  for {cloud_file, local_file} <- [
        {"plugin.yaml", "plugin.local.yaml"},
        {"manifest.json", "manifest.local.json"}
      ] do
    test "discovers #{local_file} alongside #{cloud_file} with its own configuration schema" do
      cloud_file = unquote(cloud_file)
      local_file = unquote(local_file)

      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/repos/example/catalog/contents/plugins" ->
            Req.Test.json(conn, [entry("weather", "dir")])

          "/repos/example/catalog/contents/plugins/weather" ->
            files = [cloud_file, local_file, "config.schema.json", "config.local.schema.json"]
            Req.Test.json(conn, Enum.map(files, &entry("weather/" <> &1, "file")))

          "/repos/example/catalog/releases" ->
            Req.Test.json(conn, [])

          "/raw/plugins/weather/" <> file ->
            id = if file == cloud_file, do: "weather-cloud", else: "weather-local"

            conn
            |> Plug.Conn.put_resp_content_type("text/plain")
            |> Plug.Conn.send_resp(200, manifest(file, id))
        end
      end)

      assert {:ok, plugins} =
               ForgejoSource.fetch_plugins(
                 api_base_url: "https://catalog.example.test",
                 content_base_url: nil,
                 owner: "example",
                 repo: "catalog",
                 ref: "main",
                 plugin_root: "plugins",
                 req_options: [plug: {Req.Test, __MODULE__}, retry: false]
               )

      assert [%{slug: "weather-cloud"} = cloud, %{slug: "weather-local"} = local] = plugins
      assert cloud.sample_kind == "check"
      assert local.sample_kind == "check"
      assert String.ends_with?(cloud.manifest_url, "/" <> cloud_file)
      assert String.ends_with?(local.manifest_url, "/" <> local_file)
      assert cloud.config_schema_url == raw_url("weather/config.schema.json")
      assert local.config_schema_url == raw_url("weather/config.local.schema.json")
    end
  end

  defp entry(path, type) do
    %{
      "name" => Path.basename(path),
      "path" => "plugins/" <> path,
      "type" => type,
      "html_url" => "https://catalog.example.test/source/plugins/" <> path,
      "download_url" => raw_url(path)
    }
  end

  defp raw_url(path), do: "https://catalog.example.test/raw/plugins/" <> path

  defp manifest(file, id) do
    attrs = %{
      "id" => id,
      "name" => id,
      "version" => "0.0.1",
      "description" => "Synthetic weather monitoring plugin",
      "outputs" => "plugin_result"
    }

    if Path.extname(file) == ".json" do
      Jason.encode!(attrs)
    else
      Enum.map_join(attrs, "\n", fn {key, value} -> "#{key}: #{value}" end)
    end
  end
end
