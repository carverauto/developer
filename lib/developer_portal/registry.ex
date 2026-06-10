defmodule DeveloperPortal.Registry do
  @moduledoc """
  Forgejo-backed plugin registry with an in-memory cache.
  """

  alias DeveloperPortal.Registry.Store

  @topic "registry:plugins"
  @addon_topic "registry:addons"

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

  def list_addons do
    Store.list_addons()
  end

  def featured_addons do
    list_addons()
    |> Enum.sort_by(fn addon -> if addon.official, do: 0, else: 1 end)
    |> Enum.take(3)
  end

  def get_addon(slug) do
    Enum.find(list_addons(), &(&1.slug == slug))
  end

  def filter_addons(filters) do
    Enum.filter(list_addons(), fn addon ->
      addon_match_query?(addon, Map.get(filters, "q", "")) and
        match_field?(addon.language, Map.get(filters, "language")) and
        match_field?(addon.supervision, Map.get(filters, "supervision"))
    end)
  end

  def addon_languages do
    list_addons()
    |> Enum.map(& &1.language)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def addon_supervisions do
    list_addons()
    |> Enum.map(& &1.supervision)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
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

  def subscribe_addons do
    Phoenix.PubSub.subscribe(DeveloperPortal.PubSub, @addon_topic)
  end

  def broadcast_addons(addons) do
    Phoenix.PubSub.broadcast(DeveloperPortal.PubSub, @addon_topic, {:addons_updated, addons})
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

  defp addon_match_query?(_addon, ""), do: true

  defp addon_match_query?(addon, query) do
    haystack =
      [
        addon.name,
        addon.summary,
        addon.description,
        addon.language,
        addon.supervision,
        addon.delivery
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.downcase()

    String.contains?(haystack, String.downcase(query))
  end

  defp match_field?(_value, nil), do: true
  defp match_field?(_value, ""), do: true
  defp match_field?(nil, _filter), do: false
  defp match_field?(value, filter), do: String.downcase(value) == String.downcase(filter)
end
