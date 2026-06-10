defmodule DeveloperPortalWeb.AddonLive.Show do
  use DeveloperPortalWeb, :live_view

  alias DeveloperPortal.Registry

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket), do: Registry.subscribe_addons()

    case Registry.get_addon(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Add-on not found")
         |> push_navigate(to: ~p"/addons")}

      addon ->
        {:ok,
         socket
         |> assign(:slug, slug)
         |> assign(:addon, addon)
         |> assign(:page_title, addon.name)}
    end
  end

  @impl true
  def handle_info({:addons_updated, _addons}, socket) do
    case Registry.get_addon(socket.assigns.slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Add-on not found")
         |> push_navigate(to: ~p"/addons")}

      addon ->
        {:noreply, assign(socket, :addon, addon) |> assign(:page_title, addon.name)}
    end
  end
end
