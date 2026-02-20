defmodule RumblWeb.PageController do
  use RumblWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
