defmodule DeveloperPortalWeb.PortalComponents do
  @moduledoc """
  Portal UI primitives using native Tailwind utilities and ServiceRadar
  semantic tokens. Aligned with marketing/control-plane public shell;
  does not depend on daisyUI.
  """

  use Phoenix.Component

  attr :id, :string, default: nil

  attr :variant, :atom,
    values: [:primary, :secondary, :quiet, :danger],
    default: :primary

  attr :size, :atom, values: [:small, :medium, :large], default: :medium
  attr :type, :string, default: "button"
  attr :disabled, :boolean, default: false
  attr :class, :any, default: nil

  attr :rest, :global,
    include:
      ~w(href navigate patch method download name value form target rel phx-click data-event)

  slot :inner_block, required: true

  @doc "Renders a portal action as a button or Phoenix link."
  def portal_button(%{rest: rest} = assigns) do
    assigns =
      assigns
      |> assign(:variant_class, button_variant(assigns.variant))
      |> assign(:size_class, button_size(assigns.size))
      |> assign(:link?, rest[:href] || rest[:navigate] || rest[:patch])

    ~H"""
    <.link
      :if={@link?}
      id={@id}
      class={[
        portal_button_base(),
        @variant_class,
        @size_class,
        @disabled && "pointer-events-none opacity-50",
        @class
      ]}
      aria-disabled={@disabled && "true"}
      tabindex={if(@disabled, do: "-1", else: nil)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    <button
      :if={!@link?}
      id={@id}
      type={@type}
      disabled={@disabled}
      class={[portal_button_base(), @variant_class, @size_class, @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :id, :string, default: nil
  attr :as, :string, default: "section"
  attr :tone, :atom, values: [:default, :raised, :subtle], default: :default
  attr :padding, :atom, values: [:none, :compact, :default, :spacious], default: :default
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders a surface card with restrained depth."
  def portal_surface(assigns) do
    assigns =
      assigns
      |> assign(:tone_class, surface_tone(assigns.tone))
      |> assign(:padding_class, surface_padding(assigns.padding))

    ~H"""
    <.dynamic_tag
      tag_name={@as}
      id={@id}
      class={[
        "rounded-sr-surface border border-sr-line",
        @tone_class,
        @padding_class,
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  attr :id, :string, default: nil

  attr :tone, :atom,
    values: [:default, :brand, :info, :success, :warning, :danger],
    default: :default

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @doc "Renders a compact status/meta pill."
  def portal_badge(assigns) do
    ~H"""
    <span
      id={@id}
      class={[
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium",
        badge_tone(@tone),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :id, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href target rel navigate patch method)
  slot :inner_block, required: true

  def nav_link(assigns) do
    ~H"""
    <a
      id={@id}
      class={[
        "rounded-sr-control px-3 py-2 text-sm font-medium text-sr-muted outline-none transition-colors hover:bg-sr-subtle hover:text-sr-ink focus-visible:ring-2 focus-visible:ring-sr-focus",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  defp portal_button_base do
    "inline-flex min-h-11 items-center justify-center gap-2 whitespace-nowrap rounded-sr-control font-semibold outline-none transition-[transform,background-color,color,border-color,box-shadow] duration-200 ease-sr-out focus-visible:ring-2 focus-visible:ring-sr-focus focus-visible:ring-offset-2 focus-visible:ring-offset-sr-canvas active:translate-y-px disabled:pointer-events-none disabled:opacity-50"
  end

  defp button_variant(:primary),
    do:
      "border border-sr-brand bg-sr-brand text-sr-on-brand shadow-sr-button hover:bg-sr-brand-strong hover:border-sr-brand-strong"

  defp button_variant(:secondary),
    do:
      "border border-sr-line-strong bg-sr-control text-sr-ink shadow-sr-control hover:border-sr-brand hover:text-sr-brand-strong"

  defp button_variant(:quiet),
    do:
      "border border-transparent bg-transparent text-sr-muted hover:bg-sr-subtle hover:text-sr-ink"

  defp button_variant(:danger),
    do:
      "border border-sr-danger bg-sr-danger text-sr-on-danger shadow-sr-control hover:bg-sr-danger-strong hover:border-sr-danger-strong"

  defp button_size(:small), do: "min-h-9 px-3.5 py-2 text-sm"
  defp button_size(:medium), do: "px-5 py-2.5 text-sm"
  defp button_size(:large), do: "min-h-12 px-6 py-3 text-base"

  defp surface_tone(:default), do: "bg-sr-surface shadow-sr-surface"
  defp surface_tone(:raised), do: "bg-sr-raised shadow-sr-raised"
  defp surface_tone(:subtle), do: "bg-sr-subtle"

  defp surface_padding(:none), do: "p-0"
  defp surface_padding(:compact), do: "p-4"
  defp surface_padding(:default), do: "p-6"
  defp surface_padding(:spacious), do: "p-8"

  defp badge_tone(:default), do: "border-sr-line bg-sr-subtle text-sr-muted"
  defp badge_tone(:brand), do: "border-sr-brand/30 bg-sr-brand/10 text-sr-brand"
  defp badge_tone(:info), do: "border-sr-info-line bg-sr-info-soft text-sr-info"
  defp badge_tone(:success), do: "border-sr-success-line bg-sr-success-soft text-sr-success"
  defp badge_tone(:warning), do: "border-sr-warning-line bg-sr-warning-soft text-sr-warning"
  defp badge_tone(:danger), do: "border-sr-danger-line bg-sr-danger-soft text-sr-danger"
end
