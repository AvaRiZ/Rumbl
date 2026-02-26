defmodule RumblWeb.Router do
  use RumblWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RumblWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RumblWeb.Auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RumblWeb do
    pipe_through :browser

    live "/", PageLive, :home

    live_session :authenticated,
      on_mount: [
        {RumblWeb.LiveUserAuth, :mount_current_user},
        {RumblWeb.LiveUserAuth, :ensure_authenticated}
      ] do
      live "/videos", VideoLive, :index
      live "/videos/new", VideoLive, :new
      live "/videos/:id/edit", VideoLive, :edit

      live "/users/:id/show/edit", UserLive, :edit
      live "/watch-rooms/join", WatchRoomLive, :join
      live "/watch-rooms/:code", WatchRoomLive, :show
    end

    live_session :public, on_mount: [{RumblWeb.LiveUserAuth, :mount_current_user}] do
      live "/users", UserLive, :index
      live "/users/new", UserLive, :new
      live "/users/:id", UserLive, :show

      live "/sessions/new", SessionLive, :new
      delete "/sessions", SessionController, :delete
      post "/sessions", SessionController, :create

      live "/videos/:id", VideoLive, :show
      live "/watch/:id", VideoLive, :watch
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", RumblWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rumbl, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RumblWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
