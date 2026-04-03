defmodule DeveloperPortal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        DeveloperPortalWeb.Telemetry,
        maybe_repo_child(),
        maybe_oban_child(),
        {DNSCluster,
         query: Application.get_env(:developer_portal, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: DeveloperPortal.PubSub},
        DeveloperPortal.Registry.Store,
        DeveloperPortalWeb.Endpoint
      ]
      |> Enum.reject(&is_nil/1)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DeveloperPortal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DeveloperPortalWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_repo_child do
    if Application.get_env(:developer_portal, :start_repo?, true) do
      DeveloperPortal.Repo
    end
  end

  defp maybe_oban_child do
    if Application.get_env(:developer_portal, :start_repo?, true) do
      {Oban, Application.fetch_env!(:developer_portal, Oban)}
    end
  end
end
