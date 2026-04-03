defmodule DeveloperPortal.Registry.Source do
  @moduledoc false

  alias DeveloperPortal.Registry.Plugin

  @callback fetch_plugins(keyword()) :: {:ok, [Plugin.t()]} | {:error, term()}
end
