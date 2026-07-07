defmodule DeveloperPortalWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use DeveloperPortalWeb, :html

  embed_templates "page_html/*"

  def method_badge_class("GET"), do: "badge-info"
  def method_badge_class("POST"), do: "badge-success"
  def method_badge_class("PUT"), do: "badge-secondary"
  def method_badge_class("PATCH"), do: "badge-warning"
  def method_badge_class("DELETE"), do: "badge-error"
  def method_badge_class(_method), do: "badge-outline"

  def api_display_version(nil), do: "unknown"

  def api_display_version(version) do
    version
    |> to_string()
    |> String.split(".", parts: 2)
    |> List.first()
  end

  @doc """
  Render the store's `last_error` term as a short, human-readable string so the
  "warming up" state can explain *why* the cache is empty instead of dead-ending.
  """
  def api_error_message(nil), do: nil

  def api_error_message(%{last_error: nil}), do: nil

  def api_error_message(%{last_error: reason}), do: api_error_message(reason)

  def api_error_message({:request_failed, _version, %{__struct__: struct} = exception}) do
    "Could not reach the upstream OpenAPI endpoint (#{inspect(struct)}): " <>
      Exception.message(exception)
  end

  def api_error_message({:request_failed, _version, reason}),
    do: "Could not reach the upstream OpenAPI endpoint: #{inspect(reason)}"

  def api_error_message({:unexpected_status, _version, status, _body}),
    do: "Upstream returned HTTP #{status} instead of 200."

  def api_error_message({:invalid_openapi_json, _reason}),
    do: "The upstream response was not valid JSON."

  def api_error_message({:invalid_openapi_spec, _version}),
    do: "The upstream document is missing required OpenAPI fields (openapi/paths)."

  def api_error_message({:fetch_raised, error}),
    do: "The refresh crashed while fetching: #{Exception.message(error)}"

  def api_error_message({:refresh_task_crashed, reason}),
    do: "The refresh task crashed: #{inspect(reason)}"

  def api_error_message(:no_api_doc_versions_configured),
    do: "No API documentation versions are configured."

  def api_error_message(reason), do: "Refresh failed: #{inspect(reason)}"
end
