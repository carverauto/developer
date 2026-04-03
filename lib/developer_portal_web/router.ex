defmodule DeveloperPortalWeb.Router do
  use DeveloperPortalWeb, :router

  import DeveloperPortalWeb.UserAuth

  @secure_browser_headers %{
    "content-security-policy" =>
      "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
  }

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DeveloperPortalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DeveloperPortalWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/docs", PageController, :docs_index
    get "/docs/:version", PageController, :docs
    get "/contribute", PageController, :contribute
    get "/auth/login", AuthController, :login
    get "/auth/callback", AuthController, :callback
    post "/auth/logout", AuthController, :logout
  end

  scope "/", DeveloperPortalWeb do
    pipe_through :browser

    live_session :default, on_mount: [{DeveloperPortalWeb.UserAuth, :mount_current_user}] do
      live "/plugins", PluginLive.Index, :index
      live "/plugins/:slug", PluginLive.Show, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", DeveloperPortalWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:developer_portal, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DeveloperPortalWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
