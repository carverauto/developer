defmodule DeveloperPortalWeb.PluginLive.Show do
  use DeveloperPortalWeb, :live_view

  alias DeveloperPortal.Registry
  alias DeveloperPortalWeb.Layouts

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket), do: Registry.subscribe()

    case Registry.get_plugin(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Plugin not found")
         |> push_navigate(to: ~p"/plugins")}

      plugin ->
        {:ok,
         socket
         |> assign(:slug, slug)
         |> assign(:plugin, plugin)
         |> assign(:page_title, plugin.name)}
    end
  end

  @impl true
  def handle_info({:registry_updated, _plugins}, socket) do
    case Registry.get_plugin(socket.assigns.slug) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Plugin not found")
         |> push_navigate(to: ~p"/plugins")}

      plugin ->
        {:noreply, assign(socket, :plugin, plugin) |> assign(:page_title, plugin.name)}
    end
  end
end
