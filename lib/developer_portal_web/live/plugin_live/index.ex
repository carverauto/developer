defmodule DeveloperPortalWeb.PluginLive.Index do
  use DeveloperPortalWeb, :live_view

  alias DeveloperPortal.Registry
  alias DeveloperPortalWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    filters = %{"q" => "", "type" => "", "language" => "", "category" => ""}

    if connected?(socket), do: Registry.subscribe()

    {:ok,
     socket
     |> assign(:page_title, "Plugin Directory")
     |> assign_filters(filters)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "q" => Map.get(params, "q", ""),
      "type" => Map.get(params, "type", ""),
      "language" => Map.get(params, "language", ""),
      "category" => Map.get(params, "category", "")
    }

    {:noreply, assign_filters(socket, filters)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    {:noreply, push_patch(socket, to: ~p"/plugins?#{compact_filters(filters)}")}
  end

  @impl true
  def handle_info({:registry_updated, _plugins}, socket) do
    {:noreply, assign_filters(socket, socket.assigns.filters)}
  end

  defp assign_filters(socket, filters) do
    socket
    |> assign(:filters, filters)
    |> assign(:form, to_form(filters, as: :filters))
    |> assign(:languages, Registry.languages())
    |> assign(:categories, Registry.categories())
    |> assign(:plugins, Registry.filter_plugins(filters))
  end

  defp compact_filters(filters) do
    filters
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end
end
