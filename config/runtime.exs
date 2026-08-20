import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/developer_portal start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :developer_portal, DeveloperPortalWeb.Endpoint, server: true
end

config :developer_portal, DeveloperPortalWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

github_api? = fn url ->
  is_binary(url) and String.contains?(url, "api.github.com")
end

registry_runtime_opts = fn ->
  configured =
    Application.get_env(:developer_portal, DeveloperPortal.Registry, [])
    |> Keyword.get(:source_opts, [])

  api_base_url =
    System.get_env("GITHUB_API_BASE_URL") ||
      System.get_env("FORGEJO_API_BASE_URL") ||
      Keyword.get(configured, :api_base_url)

  content_base_url =
    System.get_env("REGISTRY_CONTENT_BASE_URL") ||
      System.get_env("GITHUB_CONTENT_BASE_URL") ||
      if github_api?.(api_base_url) do
        nil
      else
        System.get_env("FORGEJO_CONTENT_BASE_URL")
      end

  [api_base_url: api_base_url, content_base_url: content_base_url]
end

if config_env() != :test do
  registry_source_opts =
    Application.get_env(:developer_portal, DeveloperPortal.Registry, [])
    |> Keyword.get(:source_opts, [])
    |> Keyword.merge(registry_runtime_opts.())

  config :developer_portal, DeveloperPortal.Registry, source_opts: registry_source_opts

  api_docs_source_opts =
    Application.get_env(:developer_portal, DeveloperPortal.ApiDocs, [])
    |> Keyword.get(:source_opts, [])
    |> then(fn source_opts ->
      versions = Keyword.get(source_opts, :versions, %{})
      v2 = Map.get(versions, "v2", Map.get(versions, "v1", %{}))

      updated_v2 =
        v2
        |> Map.put(
          "open_api_url",
          System.get_env("SERVICERADAR_API_DOCS_V2_OPENAPI_URL") ||
            System.get_env("SERVICERADAR_API_DOCS_V1_OPENAPI_URL") ||
            Map.get(v2, "open_api_url")
        )
        |> Map.put(
          "swagger_ui_url",
          System.get_env("SERVICERADAR_API_DOCS_V2_SWAGGER_URL") ||
            System.get_env("SERVICERADAR_API_DOCS_V1_SWAGGER_URL") ||
            Map.get(v2, "swagger_ui_url")
        )
        |> Map.put(
          "redoc_url",
          System.get_env("SERVICERADAR_API_DOCS_V2_REDOC_URL") ||
            System.get_env("SERVICERADAR_API_DOCS_V1_REDOC_URL") ||
            Map.get(v2, "redoc_url")
        )

      Keyword.put(
        source_opts,
        :versions,
        versions |> Map.delete("v1") |> Map.put("v2", updated_v2)
      )
    end)

  config :developer_portal, DeveloperPortal.ApiDocs, source_opts: api_docs_source_opts
end

if config_env() == :prod do
  encode_userinfo = fn value ->
    URI.encode(value, &(URI.char_unreserved?(&1) or &1 == ?- or &1 == ?_ or &1 == ?. or &1 == ?~))
  end

  database_url =
    System.get_env("DATABASE_URL") ||
      case {
        System.get_env("PGHOST"),
        System.get_env("PGPORT", "5432"),
        System.get_env("PGDATABASE"),
        System.get_env("PGUSER"),
        System.get_env("PGPASSWORD")
      } do
        {host, port, database, user, password}
        when is_binary(host) and host != "" and is_binary(database) and database != "" and
               is_binary(user) and user != "" and is_binary(password) and password != "" ->
          encoded_user = encode_userinfo.(user)
          encoded_password = encode_userinfo.(password)
          "ecto://#{encoded_user}:#{encoded_password}@#{host}:#{port}/#{database}"

        _ ->
          raise """
          environment variable DATABASE_URL is missing.
          Set DATABASE_URL directly or provide PGHOST, PGPORT, PGDATABASE, PGUSER, and PGPASSWORD.
          """
      end

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :developer_portal, DeveloperPortal.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :developer_portal, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :developer_portal, DeveloperPortalWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :developer_portal, DeveloperPortalWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :developer_portal, DeveloperPortalWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :developer_portal, DeveloperPortal.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
