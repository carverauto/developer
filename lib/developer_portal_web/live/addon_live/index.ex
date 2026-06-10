defmodule DeveloperPortalWeb.AddonLive.Index do
  use DeveloperPortalWeb, :live_view

  alias DeveloperPortal.Registry

  @impl true
  def mount(_params, _session, socket) do
    filters = %{"q" => "", "language" => "", "supervision" => ""}

    if connected?(socket), do: Registry.subscribe_addons()

    {:ok,
     socket
     |> assign(:page_title, "Add-on Catalog")
     |> assign_filters(filters)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      "q" => Map.get(params, "q", ""),
      "language" => Map.get(params, "language", ""),
      "supervision" => Map.get(params, "supervision", "")
    }

    {:noreply, assign_filters(socket, filters)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    {:noreply, push_patch(socket, to: ~p"/addons?#{compact_filters(filters)}")}
  end

  @impl true
  def handle_info({:addons_updated, _addons}, socket) do
    {:noreply, assign_filters(socket, socket.assigns.filters)}
  end

  defp assign_filters(socket, filters) do
    socket
    |> assign(:filters, filters)
    |> assign(:form, to_form(filters, as: :filters))
    |> assign(:languages, Registry.addon_languages())
    |> assign(:supervisions, Registry.addon_supervisions())
    |> assign(:addons, Registry.filter_addons(filters))
  end

  defp compact_filters(filters) do
    filters
    |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    |> Map.new()
  end
end
