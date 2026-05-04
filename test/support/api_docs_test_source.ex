defmodule DeveloperPortal.ApiDocs.TestSource do
  @moduledoc false

  @behaviour DeveloperPortal.ApiDocs.Source

  alias DeveloperPortal.ApiDocs.Document

  @impl true
  def fetch_documents(_opts) do
    {:ok,
     %{
       "v2" => %Document{
         version: "v2",
         label: "V2 API",
         title: "ServiceRadar API",
         summary:
           "Browse the current ServiceRadar API reference and download the OpenAPI document.",
         surface: "ServiceRadar API",
         openapi_version: "3.0.3",
         api_version: "2.0.0",
         source_name: "ServiceRadar",
         source_change: "add-versioned-openapi-publish",
         upstream_url: "https://demo.serviceradar.cloud/api/v2/open_api",
         swagger_ui_url: "https://demo.serviceradar.cloud/api/v2/swaggerui",
         redoc_url: "https://demo.serviceradar.cloud/api/v2/redoc",
         raw_spec: %{
           "openapi" => "3.0.3",
           "info" => %{"title" => "ServiceRadar API", "version" => "2.0.0"},
           "paths" => %{
             "/api/v2/devices" => %{
               "get" => %{
                 "summary" => "List devices",
                 "tags" => ["Inventory"],
                 "responses" => %{"200" => %{"description" => "Device collection"}}
               }
             },
             "/api/v2/alerts/{id}" => %{
               "get" => %{
                 "summary" => "Get alert",
                 "tags" => ["Monitoring"],
                 "parameters" => [
                   %{
                     "name" => "id",
                     "in" => "path",
                     "required" => true,
                     "schema" => %{"type" => "string"}
                   }
                 ],
                 "responses" => %{"200" => %{"description" => "Alert details"}}
               }
             }
           },
           "components" => %{
             "schemas" => %{
               "Device" => %{"type" => "object"},
               "Alert" => %{"type" => "object"}
             }
           },
           "servers" => [%{"url" => "https://demo.serviceradar.cloud"}]
         },
         operation_groups: [
           %{
             name: "Inventory",
             operations: [
               %{
                 id: "get:/api/v2/devices",
                 method: "GET",
                 path: "/api/v2/devices",
                 summary: "List devices",
                 description: nil,
                 tag: "Inventory",
                 deprecated?: false,
                 parameters: [],
                 request_body_types: [],
                 response_codes: [%{status: "200", description: "Device collection"}],
                 security: []
               }
             ]
           },
           %{
             name: "Monitoring",
             operations: [
               %{
                 id: "get:/api/v2/alerts/{id}",
                 method: "GET",
                 path: "/api/v2/alerts/{id}",
                 summary: "Get alert",
                 description: nil,
                 tag: "Monitoring",
                 deprecated?: false,
                 parameters: [
                   %{
                     name: "id",
                     location: "path",
                     required?: true,
                     schema: "string",
                     description: nil
                   }
                 ],
                 request_body_types: [],
                 response_codes: [%{status: "200", description: "Alert details"}],
                 security: []
               }
             ]
           }
         ],
         operation_count: 2,
         schema_count: 2,
         tag_count: 2,
         server_urls: ["https://demo.serviceradar.cloud"],
         fetched_at: ~U[2026-04-03 18:00:00Z]
       }
     }}
  end

  def version_sources(_opts) do
    %{
      "v2" => %{
        "label" => "V2 API",
        "title" => "ServiceRadar API",
        "summary" =>
          "Browse the current ServiceRadar API reference and download the OpenAPI document.",
        "surface" => "ServiceRadar API",
        "source_name" => "ServiceRadar",
        "source_change" => "add-versioned-openapi-publish",
        "open_api_url" => "https://demo.serviceradar.cloud/api/v2/open_api",
        "swagger_ui_url" => "https://demo.serviceradar.cloud/api/v2/swaggerui",
        "redoc_url" => "https://demo.serviceradar.cloud/api/v2/redoc"
      }
    }
  end
end
