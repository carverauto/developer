defmodule DeveloperPortal.ApiDocs.Store do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(opts) do
    case Keyword.get(opts, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  def documents do
    GenServer.call(__MODULE__, :documents)
  end

  def document(version) do
    GenServer.call(__MODULE__, {:document, version})
  end

  def refresh! do
    GenServer.cast(__MODULE__, :refresh)
  end

  @impl true
  def init(opts) do
    config =
      Application.get_env(:developer_portal, DeveloperPortal.ApiDocs, [])
      |> Keyword.merge(opts)

    state = %{
      documents: %{},
      source: Keyword.get(config, :source, DeveloperPortal.ApiDocs.ServiceRadarSource),
      source_opts: Keyword.get(config, :source_opts, []),
      refreshing?: false
    }

    if Keyword.get(config, :sync_init?, false) do
      {:ok, load_documents(state)}
    else
      send(self(), :refresh)
      {:ok, state}
    end
  end

  @impl true
  def handle_call(:documents, _from, state) do
    {:reply, state.documents, state}
  end

  @impl true
  def handle_call({:document, version}, _from, state) do
    {:reply, Map.get(state.documents, version), state}
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
  def handle_info({:refresh_result, {:ok, documents}}, state) do
    {:noreply, %{state | documents: documents, refreshing?: false}}
  end

  @impl true
  def handle_info({:refresh_result, {:error, reason}}, state) do
    Logger.warning("api docs refresh failed: #{inspect(reason)}")
    {:noreply, %{state | refreshing?: false}}
  end

  defp load_documents(state) do
    case state.source.fetch_documents(state.source_opts) do
      {:ok, documents} ->
        %{state | documents: documents, refreshing?: false}

      {:error, reason} ->
        Logger.warning("api docs refresh failed: #{inspect(reason)}")
        %{state | refreshing?: false}
    end
  end

  defp schedule_refresh(%{refreshing?: true} = state), do: state

  defp schedule_refresh(state) do
    parent = self()
    source = state.source
    source_opts = state.source_opts

    Task.start(fn ->
      send(parent, {:refresh_result, source.fetch_documents(source_opts)})
    end)

    %{state | refreshing?: true}
  end
end
