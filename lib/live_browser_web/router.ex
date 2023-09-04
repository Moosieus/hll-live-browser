defmodule LiveBrowserWeb.Router do
  use LiveBrowserWeb, :router

  import LiveBrowserWeb.UserAuth
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LiveBrowserWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LiveBrowserWeb do
    pipe_through :browser

    live "/", Browser
  end

  ## Authentication routes

  scope "/", LiveBrowserWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{LiveBrowserWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/admin/log_in", UserLoginLive, :new
      live "/admin/reset_password", UserForgotPasswordLive, :new
      live "/admin/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/admin/log_in", UserSessionController, :create
  end

  scope "/", LiveBrowserWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_dashboard "/dashboard",
      metrics: LiveBrowserWeb.Telemetry,
      ecto_repos: [LiveBrowser.Repo]

    live_session :require_authenticated_user,
      on_mount: [{LiveBrowserWeb.UserAuth, :ensure_authenticated}] do
      live "/admin/settings", UserSettingsLive, :edit
      live "/admin/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", LiveBrowserWeb do
    pipe_through [:browser]

    delete "/admin/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{LiveBrowserWeb.UserAuth, :mount_current_user}] do
      live "/admin/confirm/:token", UserConfirmationLive, :edit
      live "/admin/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:live_browser, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    # import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      # live_dashboard "/dashboard", metrics: LiveBrowserWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
