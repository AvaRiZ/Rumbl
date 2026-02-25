defmodule RumblWeb.PageLive do
  use RumblWeb, :live_view

  embed_templates "page_live/*"

  on_mount {RumblWeb.LiveUserAuth, :mount_current_user}

  @impl true
  def render(assigns), do: page_live(assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Home")}
  end
end
