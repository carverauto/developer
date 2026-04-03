defmodule DeveloperPortal.ApiDocs.RefreshWorker do
  @moduledoc false

  use Oban.Worker, queue: :api_docs, max_attempts: 3

  alias DeveloperPortal.ApiDocs

  @impl Oban.Worker
  def perform(_job) do
    ApiDocs.refresh!()
    :ok
  end
end
