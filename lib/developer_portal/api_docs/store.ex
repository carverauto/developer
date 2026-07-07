defmodule DeveloperPortal.ApiDocs.Store do
  @moduledoc false

  use GenServer

  require Logger

  @default_error_retry_interval :timer.minutes(1)

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

  @doc """
  Returns the refresh health of the store so the UI can surface the real
  reason the cache is empty instead of a permanent "warming up" placeholder.
  """
  def status do
    GenServer.call(__MODULE__, :status)
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
      refreshing?: false,
      task_ref: nil,
      timer_ref: nil,
      refresh_interval: Keyword.get(config, :refresh_interval),
      error_retry_interval:
        Keyword.get(config, :error_retry_interval, @default_error_retry_interval),
      last_error: nil,
      last_error_at: nil,
      last_success_at: nil,
      last_attempt_at: nil
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
  def handle_call(:status, _from, state) do
    {:reply,
     %{
       refreshing?: state.refreshing?,
       cached_versions: Map.keys(state.documents),
       last_error: state.last_error,
       last_error_at: state.last_error_at,
       last_success_at: state.last_success_at,
       last_attempt_at: state.last_attempt_at
     }, state}
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
    state =
      state
      |> demonitor_task()
      |> Map.merge(%{
        documents: documents,
        refreshing?: false,
        last_error: nil,
        last_success_at: now()
      })
      |> reschedule(:ok)

    {:noreply, state}
  end

  @impl true
  def handle_info({:refresh_result, {:error, reason}}, state) do
    Logger.warning("api docs refresh failed: #{inspect(reason)}")

    state =
      state
      |> demonitor_task()
      |> Map.merge(%{refreshing?: false, last_error: reason, last_error_at: now()})
      |> reschedule(:error)

    {:noreply, state}
  end

  # The refresh task crashed (or was killed) before it could report a result.
  # Without this clause `refreshing?` would stay `true` forever and every
  # future boot/cron refresh would be a silent no-op, leaving the cache empty.
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    state =
      if reason == :normal do
        %{state | task_ref: nil}
      else
        Logger.warning("api docs refresh task crashed: #{inspect(reason)}")

        %{
          state
          | task_ref: nil,
            refreshing?: false,
            last_error: {:refresh_task_crashed, reason},
            last_error_at: now()
        }
        |> reschedule(:error)
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp load_documents(state) do
    state = %{state | last_attempt_at: now()}

    case safe_fetch(state.source, state.source_opts) do
      {:ok, documents} ->
        %{
          state
          | documents: documents,
            refreshing?: false,
            last_error: nil,
            last_success_at: now()
        }

      {:error, reason} ->
        Logger.warning("api docs refresh failed: #{inspect(reason)}")
        %{state | refreshing?: false, last_error: reason, last_error_at: now()}
    end
  end

  defp schedule_refresh(%{refreshing?: true} = state), do: state

  defp schedule_refresh(state) do
    parent = self()
    source = state.source
    source_opts = state.source_opts

    {_pid, ref} =
      spawn_monitor(fn ->
        send(parent, {:refresh_result, safe_fetch(source, source_opts)})
      end)

    %{state | refreshing?: true, task_ref: ref, last_attempt_at: now()}
  end

  # Convert any exception/throw/exit into an `{:error, _}` tuple so a bad
  # upstream payload surfaces a real error instead of silently wedging the
  # store. Kept separate so both the sync and async paths share it.
  defp safe_fetch(source, source_opts) do
    source.fetch_documents(source_opts)
  rescue
    error -> {:error, {:fetch_raised, error}}
  catch
    kind, reason -> {:error, {:fetch_threw, kind, reason}}
  end

  defp demonitor_task(%{task_ref: nil} = state), do: state

  defp demonitor_task(%{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])
    %{state | task_ref: nil}
  end

  # Self-scheduled refresh so the cache heals on an interval even if Oban (the
  # DB-backed cron) is unavailable. Disabled unless `refresh_interval` is set,
  # which keeps tests deterministic.
  defp reschedule(state, outcome) do
    case state.refresh_interval do
      interval when is_integer(interval) and interval > 0 ->
        state = cancel_timer(state)

        wait =
          if outcome == :error,
            do: min(state.error_retry_interval, interval),
            else: interval

        %{state | timer_ref: Process.send_after(self(), :refresh, wait)}

      _ ->
        state
    end
  end

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
