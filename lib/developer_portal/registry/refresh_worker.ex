defmodule DeveloperPortal.Registry.RefreshWorker do
  @moduledoc false

  use Oban.Worker, queue: :registry, max_attempts: 3

  alias DeveloperPortal.Registry

  @impl Oban.Worker
  def perform(_job) do
    Registry.refresh!()
    :ok
  end
end
