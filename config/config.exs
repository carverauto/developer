# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :developer_portal,
  ecto_repos: [DeveloperPortal.Repo],
  generators: [timestamp_type: :utc_datetime]

config :developer_portal, DeveloperPortal.Registry,
  source: DeveloperPortal.Registry.ForgejoSource,
  source_opts: [
    api_base_url: "https://api.github.com",
    owner: "carverauto",
    repo: "serviceradar",
    ref: "staging",
    plugin_root: "go/cmd/wasm-plugins",
    addon_root: "addons",
    default_author: "ServiceRadar",
    default_type: "official",
    wasm_index_asset: "serviceradar-wasm-plugin-index.json",
    addon_index_asset: "serviceradar-native-addon-index.json",
    releases_limit: 20,
    req_options: [receive_timeout: 15_000]
  ]

config :developer_portal, DeveloperPortal.ApiDocs,
  source: DeveloperPortal.ApiDocs.ServiceRadarSource,
  source_opts: [
    versions: %{
      "v2" => %{
        "label" => "V2 API",
        "title" => "ServiceRadar API",
        "summary" =>
          "Browse the current ServiceRadar API reference and download the OpenAPI document.",
        "surface" => "ServiceRadar API",
        "source_name" => "ServiceRadar",
        "source_change" => "add-versioned-openapi-publish",
        # Prefer the committed artifact from the serviceradar repo on GitHub.
        # Override per environment with SERVICERADAR_API_DOCS_V2_OPENAPI_URL.
        # When remote fetch fails (common in-cluster), fall back to the bundled
        # copy under priv/static/api so /docs/v2/api/openapi.json never 503s.
        "open_api_url" =>
          "https://raw.githubusercontent.com/carverauto/serviceradar/staging/elixir/web-ng/priv/static/openapi.json",
        "fallback_path" => "priv/static/api/openapi-v2.json"
        # swagger_ui_url / redoc_url intentionally omitted: demo UIs are auth-gated.
        # Portal embeds Swagger UI from the cached/bundled spec.
      }
    },
    req_options: [receive_timeout: 30_000]
  ],
  sync_init?: false,
  # Self-healing refresh cadence (independent of the Oban cron below). On error
  # the store retries after `error_retry_interval` instead of waiting a full
  # interval, so a transient upstream blip recovers quickly.
  refresh_interval: :timer.minutes(15),
  error_retry_interval: :timer.minutes(1)

config :developer_portal, Oban,
  repo: DeveloperPortal.Repo,
  queues: [registry: 5, api_docs: 3],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"*/15 * * * *", DeveloperPortal.Registry.RefreshWorker},
       {"*/15 * * * *", DeveloperPortal.ApiDocs.RefreshWorker}
     ]}
  ]

# Configure the endpoint
config :developer_portal, DeveloperPortalWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DeveloperPortalWeb.ErrorHTML, json: DeveloperPortalWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DeveloperPortal.PubSub,
  live_view: [signing_salt: "LgiVyFqE"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :developer_portal, DeveloperPortal.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  developer_portal: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  developer_portal: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
