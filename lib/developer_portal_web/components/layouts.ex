defmodule DeveloperPortalWeb.Layouts do
  @moduledoc """
  Layouts and shell chrome for the developer portal.
  """
  use DeveloperPortalWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div
      id="portal-app-shell"
      class="sr-public-shell min-h-[100dvh] bg-sr-canvas font-sans text-sr-ink"
    >
      <a
        id="portal-skip-link"
        href="#main-content"
        class="fixed left-4 top-3 z-[var(--sr-z-skip)] inline-flex min-h-11 -translate-y-24 items-center rounded-sr-control bg-sr-ink px-4 py-2.5 text-sm font-semibold text-sr-canvas shadow-sr-raised outline-none transition-transform duration-200 ease-sr-out focus:translate-y-0"
      >
        Skip to content
      </a>

      <header class="sticky top-0 z-[var(--sr-z-shell)] border-b border-sr-line bg-sr-surface/90 backdrop-blur">
        <div class="mx-auto flex min-h-16 max-w-[1280px] items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <a
            href={~p"/"}
            id="portal-brand-link"
            class="group flex min-h-11 shrink-0 items-center gap-3 rounded-sr-control outline-none focus-visible:ring-2 focus-visible:ring-sr-focus focus-visible:ring-offset-2 focus-visible:ring-offset-sr-canvas"
          >
            <div class="flex size-10 items-center justify-center rounded-sr-control border border-sr-line bg-sr-control shadow-sr-control">
              <img
                id="portal-brand-logo"
                src={~p"/images/logo.svg"}
                width="28"
                height="28"
                alt=""
                aria-hidden="true"
                class="size-7 shrink-0"
              />
            </div>
            <div class="min-w-0">
              <p class="text-sm font-semibold tracking-tight text-sr-ink sm:text-[1.05rem]">
                ServiceRadar
              </p>
              <p class="hidden text-xs leading-tight text-sr-muted sm:block">
                Developer Portal
              </p>
            </div>
          </a>

          <nav
            id="portal-desktop-navigation"
            aria-label="Primary navigation"
            class="hidden items-center gap-1 md:flex"
          >
            <.nav_link href={~p"/docs/v2"}>Docs</.nav_link>
            <.nav_link href={~p"/plugins"}>Plugins</.nav_link>
            <.nav_link href={~p"/addons"}>Add-ons</.nav_link>
            <.nav_link href={~p"/contribute"}>Contribute</.nav_link>
            <.nav_link
              href="https://docs.serviceradar.cloud"
              target="_blank"
              rel="noopener noreferrer"
            >
              Product docs
            </.nav_link>
          </nav>

          <details id="portal-mobile-navigation" class="group relative md:hidden">
            <summary
              id="portal-mobile-navigation-toggle"
              class="inline-flex min-h-11 cursor-pointer list-none items-center gap-2 rounded-sr-control border border-sr-line bg-sr-control px-3.5 text-sm font-medium text-sr-ink shadow-sr-control outline-none transition-colors duration-200 ease-sr-out hover:border-sr-line-hover focus-visible:ring-2 focus-visible:ring-sr-focus [&::-webkit-details-marker]:hidden"
            >
              <span class="sr-only group-open:hidden">Open navigation</span>
              <span class="sr-only hidden group-open:inline">Close navigation</span> Menu
            </summary>
            <div class="absolute right-0 z-[var(--sr-z-menu)] mt-2 w-60 rounded-sr-surface border border-sr-line bg-sr-raised p-2 shadow-sr-raised">
              <div class="grid gap-0.5">
                <.nav_link href={~p"/docs/v2"} class="w-full justify-start">Docs</.nav_link>
                <.nav_link href={~p"/plugins"} class="w-full justify-start">Plugins</.nav_link>
                <.nav_link href={~p"/addons"} class="w-full justify-start">Add-ons</.nav_link>
                <.nav_link href={~p"/contribute"} class="w-full justify-start">Contribute</.nav_link>
                <.nav_link
                  href="https://docs.serviceradar.cloud"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="w-full justify-start"
                >
                  Product docs
                </.nav_link>
              </div>
            </div>
          </details>
        </div>
      </header>

      <main id="main-content" class="relative z-[var(--sr-z-content)]">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-sr-line px-4 py-10 sm:px-6 lg:px-8">
        <div class="mx-auto flex max-w-[1280px] flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
          <div class="space-y-2">
            <p class="text-sm font-semibold text-sr-ink">ServiceRadar Developer Portal</p>
            <p class="max-w-md text-sm leading-6 text-sr-muted">
              Docs, SDKs, plugins, and native add-ons for building on ServiceRadar.
            </p>
            <p class="text-xs text-sr-muted">
              © {Date.utc_today().year} Carver Automation Corporation. All rights reserved.
            </p>
            <p class="text-xs text-sr-muted">
              ServiceRadar® is a registered trademark of Carver Automation Corporation.
            </p>
          </div>
          <div class="flex flex-wrap gap-x-5 gap-y-2 text-sm">
            <a
              href="https://serviceradar.cloud"
              class="font-medium text-sr-muted outline-none transition-colors hover:text-sr-ink focus-visible:ring-2 focus-visible:ring-sr-focus"
            >
              Marketing site
            </a>
            <a
              href="https://docs.serviceradar.cloud"
              class="font-medium text-sr-muted outline-none transition-colors hover:text-sr-ink focus-visible:ring-2 focus-visible:ring-sr-focus"
            >
              Product docs
            </a>
            <a
              href="https://github.com/carverauto/serviceradar"
              class="font-medium text-sr-muted outline-none transition-colors hover:text-sr-ink focus-visible:ring-2 focus-visible:ring-sr-focus"
            >
              Source
            </a>
            <a
              href="https://demo.serviceradar.cloud"
              class="font-medium text-sr-muted outline-none transition-colors hover:text-sr-ink focus-visible:ring-2 focus-visible:ring-sr-focus"
            >
              Demo
            </a>
          </div>
        </div>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
