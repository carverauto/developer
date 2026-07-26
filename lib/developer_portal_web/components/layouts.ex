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
    <div class="sr-public-shell min-h-dvh">
      <a
        href="#main-content"
        class="sr-skip-link fixed left-4 top-4 z-[var(--sr-z-skip)] -translate-y-16 rounded-sr-control border border-sr-line bg-sr-raised px-4 py-2 text-sm font-semibold text-sr-ink shadow-sr-raised outline-none transition focus:translate-y-0 focus-visible:ring-2 focus-visible:ring-sr-focus"
      >
        Skip to content
      </a>

      <header class="sticky top-0 z-[var(--sr-z-shell)] border-b border-sr-line bg-sr-surface/90 backdrop-blur-md">
        <div class="mx-auto flex max-w-[1280px] items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
          <a
            href={~p"/"}
            class="flex min-w-0 items-center gap-3 outline-none focus-visible:ring-2 focus-visible:ring-sr-focus"
          >
            <div class="flex size-11 shrink-0 items-center justify-center rounded-sr-control border border-sr-line bg-sr-control shadow-sr-control">
              <img
                src={~p"/images/logo.svg"}
                alt="ServiceRadar"
                class="size-7"
                width="28"
                height="28"
              />
            </div>
            <div class="min-w-0">
              <p class="text-xs font-semibold uppercase tracking-[0.2em] text-sr-brand">
                ServiceRadar
              </p>
              <p class="truncate text-base font-semibold tracking-tight text-sr-ink">
                Developer Portal
              </p>
            </div>
          </a>

          <nav class="hidden items-center gap-1 md:flex" aria-label="Primary">
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
            <.theme_toggle />
          </nav>

          <details id="portal-mobile-nav" class="relative md:hidden">
            <summary class="list-none cursor-pointer rounded-sr-control border border-sr-line bg-sr-control px-3 py-2 text-sm font-semibold text-sr-ink shadow-sr-control outline-none focus-visible:ring-2 focus-visible:ring-sr-focus [&::-webkit-details-marker]:hidden">
              Menu
            </summary>
            <div class="absolute right-0 mt-2 w-56 rounded-sr-surface border border-sr-line bg-sr-raised p-2 shadow-sr-raised">
              <div class="grid gap-1">
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
                <div class="border-t border-sr-line pt-2">
                  <.theme_toggle />
                </div>
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

  def theme_toggle(assigns) do
    ~H"""
    <div
      class="inline-flex items-center rounded-full border border-sr-line bg-sr-subtle p-0.5 shadow-sr-control"
      role="group"
      aria-label="Color theme"
    >
      <button
        type="button"
        class="rounded-full px-2.5 py-1.5 text-sr-muted outline-none transition-colors hover:text-sr-ink focus-visible:ring-2 focus-visible:ring-sr-focus"
        data-theme-choice="light"
        aria-label="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>
      <button
        type="button"
        class="rounded-full px-2.5 py-1.5 text-sr-muted outline-none transition-colors hover:text-sr-ink focus-visible:ring-2 focus-visible:ring-sr-focus"
        data-theme-choice="dark"
        aria-label="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
