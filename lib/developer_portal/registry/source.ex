defmodule DeveloperPortal.Registry.Source do
  @moduledoc false

  alias DeveloperPortal.Registry.Addon
  alias DeveloperPortal.Registry.Plugin

  @callback fetch_plugins(keyword()) :: {:ok, [Plugin.t()]} | {:error, term()}
  @callback fetch_addons(keyword()) :: {:ok, [Addon.t()]} | {:error, term()}
end
