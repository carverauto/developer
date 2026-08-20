defmodule DeveloperPortal.Registry.PublicURL do
  @moduledoc false

  @forgejo_hosts ~w(code.carverauto.dev git.carverauto.dev)

  @doc """
  Rewrites ServiceRadar Forgejo browse/raw URLs onto GitHub.

  Fetching can still use the original URL (or an internal content host). This
  only changes what the portal shows to humans.
  """
  @spec githubize(String.t() | nil) :: String.t() | nil
  def githubize(nil), do: nil
  def githubize(""), do: nil

  def githubize(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.host in @forgejo_hosts and
         String.contains?(uri.path || "", "/carverauto/serviceradar/") do
      rewrite_serviceradar(uri)
    else
      url
    end
  end

  defp rewrite_serviceradar(%URI{path: path, query: query, fragment: fragment}) do
    github_path =
      path
      |> String.replace(
        ~r"^/carverauto/serviceradar/src/branch/",
        "/carverauto/serviceradar/tree/"
      )
      |> String.replace(
        ~r"^/carverauto/serviceradar/src/commit/",
        "/carverauto/serviceradar/blob/"
      )
      |> String.replace(
        ~r"^/carverauto/serviceradar/raw/branch/",
        "/carverauto/serviceradar/blob/"
      )
      |> String.replace(
        ~r"^/carverauto/serviceradar/raw/commit/",
        "/carverauto/serviceradar/blob/"
      )

    %URI{
      scheme: "https",
      host: "github.com",
      path: github_path,
      query: query,
      fragment: fragment
    }
    |> URI.to_string()
  end
end
