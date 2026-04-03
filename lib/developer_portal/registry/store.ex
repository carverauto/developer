defmodule DeveloperPortal.Registry.Store do
  @moduledoc false

  use GenServer

  require Logger

  alias DeveloperPortal.Registry
  alias DeveloperPortal.Registry.Validator

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end

  def refresh! do
    GenServer.cast(__MODULE__, :refresh)
  end

  @impl true
  def init(_state) do
    config = Application.get_env(:developer_portal, DeveloperPortal.Registry, [])

    state = %{
      plugins: [],
      source: Keyword.get(config, :source, DeveloperPortal.Registry.ForgejoSource),
      source_opts: Keyword.get(config, :source_opts, []),
      refreshing?: false
    }

    if Keyword.get(config, :sync_init?, false) do
      {:ok, load_plugins(state)}
    else
      send(self(), :refresh)
      {:ok, state}
    end
  end

  @impl true
  def handle_call(:list_plugins, _from, state) do
    {:reply, state.plugins, state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    {:noreply, schedule_refresh(state)}
  end

  @impl true
  def handle_info(:refresh, state) do
    {:noreply, schedule_refresh(state)}
  end

  @impl true
  def handle_info({:refresh_result, {:ok, plugins}}, state) do
    plugins = Validator.validate!(plugins)

    if plugins != state.plugins do
      Registry.broadcast_refresh(plugins)
    end

    {:noreply, %{state | plugins: plugins, refreshing?: false}}
  end

  @impl true
  def handle_info({:refresh_result, {:error, reason}}, state) do
    Logger.warning("plugin registry refresh failed: #{inspect(reason)}")
    {:noreply, %{state | refreshing?: false}}
  end

  defp load_plugins(state) do
    case state.source.fetch_plugins(state.source_opts) do
      {:ok, plugins} ->
        %{state | plugins: Validator.validate!(plugins), refreshing?: false}

      {:error, reason} ->
        Logger.warning("plugin registry refresh failed: #{inspect(reason)}")
        %{state | refreshing?: false}
    end
  end

  defp schedule_refresh(%{refreshing?: true} = state), do: state

  defp schedule_refresh(state) do
    parent = self()
    source = state.source
    source_opts = state.source_opts

    Task.start(fn ->
      send(parent, {:refresh_result, source.fetch_plugins(source_opts)})
    end)

    %{state | refreshing?: true}
  end
end
