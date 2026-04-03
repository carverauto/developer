defmodule DeveloperPortal.Registry.Plugin do
  @moduledoc "Simple plugin metadata structure for the initial registry."

  @enforce_keys [
    :slug,
    :name,
    :author,
    :version,
    :summary,
    :description,
    :type,
    :language,
    :category
  ]
  defstruct [
    :slug,
    :name,
    :author,
    :version,
    :summary,
    :description,
    :type,
    :language,
    :category,
    :signed,
    :source_url,
    :readme_url,
    :manifest_url,
    :config_schema_url,
    :wasm_url,
    :artifact_url,
    :signature_url,
    :installation,
    :official,
    :runtime,
    :entrypoint,
    :outputs,
    :capabilities,
    :allowed_domains,
    :allowed_ports,
    :sample_kind
  ]

  @type t :: %__MODULE__{}
end
