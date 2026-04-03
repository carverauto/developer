defmodule DeveloperPortal.ApiDocs.FlakyTestSource do
  @moduledoc false

  @behaviour DeveloperPortal.ApiDocs.Source

  @impl true
  def fetch_documents(opts) do
    agent = Keyword.fetch!(opts, :agent)

    Agent.get_and_update(agent, fn
      [result | rest] -> {result, rest}
      [] -> {{:error, :no_more_results}, []}
    end)
  end
end
