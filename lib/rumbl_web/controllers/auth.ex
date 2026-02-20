defmodule RumblWeb.Auth do
  @moduledoc """
  Authentication plug for managing user sessions.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias Rumbl.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    cond do
      # Already assigned (e.g., in tests)
      conn.assigns[:current_user] ->
        conn

      # Has session, fetch user
      user = user_id && Accounts.get_user(user_id) ->
        assign(conn, :current_user, user)

      # No session
      true ->
        assign(conn, :current_user, nil)
    end
  end

  @doc """
  Logs in a user by putting user_id in session.
  """
  def login(conn, user) do
    conn
    |> put_session(:user_id, user.id)
    |> configure_session(renew: true)
    |> assign(:current_user, user)
  end

  @doc """
  Logs out by dropping the session.
  """
  def logout(conn) do
    configure_session(conn, drop: true)
  end

  @doc """
  Plug to require authenticated user.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: "/sessions/new")
      |> halt()
    end
  end

  @doc """
  Plug to redirect if already authenticated.
  """
  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: "/")
      |> halt()
    else
      conn
    end
  end
end
