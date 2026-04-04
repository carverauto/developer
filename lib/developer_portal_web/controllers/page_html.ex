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
end
