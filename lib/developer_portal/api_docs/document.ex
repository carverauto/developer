defmodule DeveloperPortal.ApiDocs.Document do
  @moduledoc false

  @type operation_parameter :: %{
          name: String.t(),
          location: String.t(),
          required?: boolean(),
          schema: String.t() | nil,
          description: String.t() | nil
        }

  @type operation_response :: %{
          status: String.t(),
          description: String.t()
        }

  @type operation :: %{
          id: String.t(),
          method: String.t(),
          path: String.t(),
          summary: String.t(),
          description: String.t() | nil,
          tag: String.t(),
          deprecated?: boolean(),
          parameters: [operation_parameter()],
          request_body_types: [String.t()],
          response_codes: [operation_response()],
          security: [String.t()]
        }

  @type operation_group :: %{name: String.t(), operations: [operation()]}

  @type t :: %__MODULE__{
          version: String.t(),
          label: String.t(),
          title: String.t(),
          summary: String.t(),
          surface: String.t(),
          openapi_version: String.t(),
          api_version: String.t(),
          source_name: String.t(),
          source_change: String.t() | nil,
          upstream_url: String.t(),
          swagger_ui_url: String.t() | nil,
          redoc_url: String.t() | nil,
          raw_spec: map(),
          operation_groups: [operation_group()],
          operation_count: non_neg_integer(),
          schema_count: non_neg_integer(),
          tag_count: non_neg_integer(),
          server_urls: [String.t()] | nil,
          fetched_at: DateTime.t()
        }

  @enforce_keys [
    :version,
    :label,
    :title,
    :summary,
    :surface,
    :openapi_version,
    :api_version,
    :source_name,
    :upstream_url,
    :raw_spec,
    :operation_groups,
    :operation_count,
    :schema_count,
    :tag_count,
    :fetched_at
  ]
  defstruct [
    :version,
    :label,
    :title,
    :summary,
    :surface,
    :openapi_version,
    :api_version,
    :source_name,
    :source_change,
    :upstream_url,
    :swagger_ui_url,
    :redoc_url,
    :raw_spec,
    :operation_groups,
    :operation_count,
    :schema_count,
    :tag_count,
    :server_urls,
    :fetched_at
  ]
end
