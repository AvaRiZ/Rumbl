defmodule RumblWeb.LiveUserAuth do
  @moduledoc """
  Authentication helpers for LiveView sessions.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  alias Rumbl.Accounts

  def on_mount(:mount_current_user, _params, session, socket) do
    user =
      case session do
        %{"user_id" => user_id} -> Accounts.get_user(user_id)
        _ -> nil
      end

    {:cont, assign(socket, :current_user, user)}
  end

  def on_mount(:ensure_authenticated, _params, _session, socket) do
    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be logged in to access this page")
       |> redirect(to: "/sessions/new")}
    end
  end
end
