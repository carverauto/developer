defmodule DeveloperPortal.Registry.Store do
  @moduledoc false

  use GenServer

  require Logger

  alias DeveloperPortal.Registry

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end

  def refresh! do
    GenServer.call(__MODULE__, :refresh)
  end

  @impl true
  def init(_state) do
    config = Application.get_env(:developer_portal, DeveloperPortal.Registry, [])

    state = %{
      plugins: [],
      source: Keyword.get(config, :source, DeveloperPortal.Registry.ForgejoSource),
      source_opts: Keyword.get(config, :source_opts, [])
    }

    state = refresh_plugins(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:list_plugins, _from, state) do
    {:reply, state.plugins, state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    new_state = refresh_plugins(state)
    {:reply, new_state.plugins, new_state}
  end

  defp refresh_plugins(state) do
    case state.source.fetch_plugins(state.source_opts) do
      {:ok, plugins} ->
        if plugins != state.plugins do
          Registry.broadcast_refresh(plugins)
        end

        %{state | plugins: plugins}

      {:error, reason} ->
        Logger.warning("plugin registry refresh failed: #{inspect(reason)}")
        state
    end
  end
end
