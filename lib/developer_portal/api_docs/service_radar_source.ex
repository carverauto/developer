defmodule DeveloperPortal.ApiDocs.ServiceRadarSource do
  @moduledoc false

  @behaviour DeveloperPortal.ApiDocs.Source

  alias DeveloperPortal.ApiDocs.Document

  @http_methods ~w(get post put patch delete options head trace)

  @impl true
  def fetch_documents(opts) do
    with {:ok, config} <- build_config(opts) do
      Enum.reduce_while(config.versions, {:ok, %{}}, fn {version, attrs}, {:ok, documents} ->
        case fetch_document(version, attrs, config.req_options) do
          {:ok, document} ->
            {:cont, {:ok, Map.put(documents, version, document)}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)
    end
  end

  def version_sources(opts) do
    case build_config(opts) do
      {:ok, config} -> config.versions
      {:error, _reason} -> %{}
    end
  end

  defp build_config(opts) do
    merged =
      Application.get_env(:developer_portal, DeveloperPortal.ApiDocs, [])
      |> Keyword.get(:source_opts, [])
      |> Keyword.merge(opts)

    versions =
      merged
      |> Keyword.get(:versions, %{})
      |> Enum.into(%{}, fn {version, attrs} ->
        {version, normalize_attrs(attrs)}
      end)

    with :ok <- validate_versions(versions) do
      {:ok,
       %{
         versions: versions,
         req_options: Keyword.get(merged, :req_options, [])
       }}
    end
  rescue
    error in KeyError -> {:error, error}
  end

  defp validate_versions(versions) when map_size(versions) == 0 do
    {:error, :no_api_doc_versions_configured}
  end

  defp validate_versions(versions) do
    Enum.reduce_while(versions, :ok, fn {version, attrs}, :ok ->
      with :ok <- validate_url(version, Map.fetch!(attrs, "open_api_url"), :open_api_url),
           :ok <-
             validate_optional_url(version, Map.get(attrs, "swagger_ui_url"), :swagger_ui_url),
           :ok <- validate_optional_url(version, Map.get(attrs, "redoc_url"), :redoc_url) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_url(version, url, field) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] and is_binary(uri.host) do
      :ok
    else
      {:error, {:invalid_source_url, version, field, url}}
    end
  end

  defp validate_url(version, url, field), do: {:error, {:invalid_source_url, version, field, url}}

  defp validate_optional_url(_version, nil, _field), do: :ok
  defp validate_optional_url(version, url, field), do: validate_url(version, url, field)

  defp fetch_document(version, attrs, req_options) do
    case Req.get(Map.fetch!(attrs, "open_api_url"), req_options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        with {:ok, spec} <- decode_spec(body),
             :ok <- validate_spec(spec, version) do
          {:ok, build_document(version, attrs, spec)}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:unexpected_status, version, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, version, reason}}
    end
  end

  defp decode_spec(body) when is_map(body), do: {:ok, normalize_keys(body)}

  defp decode_spec(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, spec} when is_map(spec) -> {:ok, normalize_keys(spec)}
      {:ok, _other} -> {:error, :invalid_openapi_body}
      {:error, reason} -> {:error, {:invalid_openapi_json, reason}}
    end
  end

  defp validate_spec(%{"openapi" => _openapi, "paths" => paths}, _version) when is_map(paths),
    do: :ok

  defp validate_spec(_spec, version), do: {:error, {:invalid_openapi_spec, version}}

  defp build_document(version, attrs, spec) do
    operation_groups =
      spec
      |> Map.get("paths", %{})
      |> Enum.flat_map(&build_operations/1)
      |> Enum.group_by(& &1.tag)
      |> Enum.map(fn {tag, operations} ->
        %{name: tag, operations: Enum.sort_by(operations, &{&1.path, method_rank(&1.method)})}
      end)
      |> Enum.sort_by(& &1.name)

    %Document{
      version: version,
      label: Map.get(attrs, "label", String.upcase(version)),
      title: get_in(spec, ["info", "title"]) || Map.get(attrs, "title", "ServiceRadar API"),
      summary:
        Map.get(
          attrs,
          "summary",
          "Browse the current ServiceRadar API reference and download the OpenAPI document."
        ),
      surface: Map.get(attrs, "surface", "ServiceRadar API"),
      openapi_version: Map.get(spec, "openapi", "3.0.3"),
      api_version: get_in(spec, ["info", "version"]) || Map.get(attrs, "api_version", "unknown"),
      source_name: Map.get(attrs, "source_name", "ServiceRadar"),
      source_change: Map.get(attrs, "source_change", "add-versioned-openapi-publish"),
      upstream_url: Map.fetch!(attrs, "open_api_url"),
      swagger_ui_url: Map.get(attrs, "swagger_ui_url"),
      redoc_url: Map.get(attrs, "redoc_url"),
      raw_spec: spec,
      operation_groups: operation_groups,
      operation_count:
        Enum.reduce(operation_groups, 0, fn group, acc -> acc + length(group.operations) end),
      schema_count: spec |> get_in(["components", "schemas"]) |> count_entries(),
      tag_count: length(operation_groups),
      server_urls:
        spec
        |> Map.get("servers", [])
        |> Enum.map(&Map.get(&1, "url"))
        |> Enum.reject(&is_nil/1),
      fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  defp build_operations({path, methods}) when is_map(methods) do
    methods
    |> Enum.filter(fn {method, details} -> method in @http_methods and is_map(details) end)
    |> Enum.map(fn {method, details} ->
      %{
        id: Map.get(details, "operationId", "#{method}:#{path}"),
        method: String.upcase(method),
        path: path,
        summary: Map.get(details, "summary", "#{String.upcase(method)} #{path}"),
        description: Map.get(details, "description"),
        tag: details |> Map.get("tags", ["General"]) |> List.first() || "General",
        deprecated?: Map.get(details, "deprecated", false),
        parameters:
          details
          |> Map.get("parameters", [])
          |> Enum.map(&build_parameter/1),
        request_body_types:
          details
          |> Map.get("requestBody")
          |> request_body_types(),
        response_codes:
          details
          |> Map.get("responses", %{})
          |> build_responses(),
        security:
          details
          |> Map.get("security", [])
          |> build_security_labels()
      }
    end)
  end

  defp build_parameter(parameter) when is_map(parameter) do
    %{
      name: Map.get(parameter, "name", "param"),
      location: Map.get(parameter, "in", "query"),
      required?: Map.get(parameter, "required", false),
      schema: parameter |> Map.get("schema") |> schema_label(),
      description: Map.get(parameter, "description")
    }
  end

  defp request_body_types(nil), do: []

  defp request_body_types(request_body) when is_map(request_body) do
    request_body
    |> Map.get("content", %{})
    |> Map.keys()
    |> Enum.sort()
  end

  defp build_responses(responses) when is_map(responses) do
    responses
    |> Enum.map(fn {status, details} ->
      %{
        status: status,
        description:
          details
          |> Map.get("description", "No description")
      }
    end)
    |> Enum.sort_by(&response_sort_key(&1.status))
  end

  defp build_security_labels(requirements) when is_list(requirements) do
    requirements
    |> Enum.flat_map(fn requirement ->
      requirement
      |> Map.keys()
      |> Enum.map(&to_string/1)
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp response_sort_key("default"), do: 9_999

  defp response_sort_key(status) do
    case Integer.parse(to_string(status)) do
      {value, ""} -> value
      _ -> 9_998
    end
  end

  defp method_rank("GET"), do: 0
  defp method_rank("POST"), do: 1
  defp method_rank("PUT"), do: 2
  defp method_rank("PATCH"), do: 3
  defp method_rank("DELETE"), do: 4
  defp method_rank("OPTIONS"), do: 5
  defp method_rank("HEAD"), do: 6
  defp method_rank("TRACE"), do: 7
  defp method_rank(_method), do: 8

  defp count_entries(nil), do: 0
  defp count_entries(entries) when is_map(entries), do: map_size(entries)

  defp schema_label(nil), do: nil

  defp schema_label(%{"$ref" => ref}) do
    ref
    |> String.split("/")
    |> List.last()
  end

  defp schema_label(%{"type" => type}) when is_binary(type), do: type
  defp schema_label(_schema), do: nil

  defp normalize_attrs(attrs) when is_list(attrs),
    do: attrs |> Enum.into(%{}) |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp normalize_keys(value) when is_map(value) do
    Map.new(value, fn {key, child} ->
      {to_string(key), normalize_keys(child)}
    end)
  end

  defp normalize_keys(value) when is_list(value), do: Enum.map(value, &normalize_keys/1)
  defp normalize_keys(value), do: value
end
