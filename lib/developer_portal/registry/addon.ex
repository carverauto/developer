defmodule DeveloperPortal.Registry.Addon do
  @moduledoc """
  Published native add-on metadata.

  Add-ons are sourced from the signed `serviceradar-native-addon-index.json`
  release asset (the authoritative record of which add-ons have signed,
  published OCI artifacts) enriched with the `addon.yaml` manifest checked into
  the repository.
  """

  @enforce_keys [
    :slug,
    :name,
    :summary,
    :description,
    :version,
    :language,
    :kind
  ]
  defstruct [
    :slug,
    :name,
    :summary,
    :description,
    :version,
    :language,
    :kind,
    :delivery,
    :supervision,
    :capabilities,
    :platforms,
    :architectures,
    :artifacts,
    :signed,
    :oci_ref,
    :oci_digest,
    :bundle_digest,
    :source_url,
    :readme_url,
    :docs_path,
    :official
  ]

  @type artifact :: %{
          os: String.t(),
          arch: String.t(),
          signature_digest: String.t() | nil,
          sha256: String.t() | nil
        }

  @type t :: %__MODULE__{}
end
