defmodule DeveloperPortal.Registry do
  @moduledoc """
  Forgejo-backed plugin registry with an in-memory cache.
  """

  alias DeveloperPortal.Registry.Store

  @topic "registry:plugins"

  def list_plugins do
    Store.list_plugins()
  end

  def featured_plugins do
    list_plugins()
    |> Enum.sort_by(fn plugin -> if plugin.official, do: 0, else: 1 end)
    |> Enum.take(3)
  end

  def get_plugin(slug) do
    Enum.find(list_plugins(), &(&1.slug == slug))
  end

  def filter_plugins(filters) do
    Enum.filter(list_plugins(), fn plugin ->
      match_query?(plugin, Map.get(filters, "q", "")) and
        match_field?(plugin.type, Map.get(filters, "type")) and
        match_field?(plugin.language, Map.get(filters, "language")) and
        match_field?(plugin.category, Map.get(filters, "category"))
    end)
  end

  def languages do
    list_plugins() |> Enum.map(& &1.language) |> Enum.uniq() |> Enum.sort()
  end

  def categories do
    list_plugins() |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.sort()
  end

  def subscribe do
    Phoenix.PubSub.subscribe(DeveloperPortal.PubSub, @topic)
  end

  def broadcast_refresh(plugins) do
    Phoenix.PubSub.broadcast(DeveloperPortal.PubSub, @topic, {:registry_updated, plugins})
  end

  def refresh! do
    Store.refresh!()
  end

  defp match_query?(_plugin, ""), do: true

  defp match_query?(plugin, query) do
    haystack =
      [
        plugin.name,
        plugin.author,
        plugin.summary,
        plugin.description,
        plugin.category,
        plugin.language
      ]
      |> Enum.join(" ")
      |> String.downcase()

    String.contains?(haystack, String.downcase(query))
  end

  defp match_field?(_value, nil), do: true
  defp match_field?(_value, ""), do: true
  defp match_field?(value, filter), do: String.downcase(value) == String.downcase(filter)
end
