import Config

config :developer_portal, :start_repo?, false

config :developer_portal, DeveloperPortal.Registry,
  source: DeveloperPortal.Registry.TestSource,
  source_opts: []

config :developer_portal, Oban,
  repo: DeveloperPortal.Repo,
  testing: :manual,
  queues: false,
  plugins: false

config :developer_portal, DeveloperPortal.Auth,
  provider: DeveloperPortal.Auth.TestProvider,
  provider_opts: [
    enabled?: true,
    required_group: "serviceradar-developer",
    user: %{
      "sub" => "user-123",
      "email" => "dev@example.com",
      "name" => "Portal Developer",
      "preferred_username" => "portaldev",
      "groups" => ["serviceradar-developer", "engineering"]
    }
  ]

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :developer_portal, DeveloperPortal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "developer_portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :developer_portal, DeveloperPortalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "8M4zTo+vVSc8XETl1fqsVvpacGi+rs7wG6wT+HAP5tlVlJjYjKOZD52LIC9d1cqJ",
  server: false

# In test we don't send emails
config :developer_portal, DeveloperPortal.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
