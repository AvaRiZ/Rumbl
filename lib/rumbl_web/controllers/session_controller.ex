defmodule RumblWeb.SessionController do
  use RumblWeb, :controller

  alias Rumbl.Accounts
  alias RumblWeb.Auth

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"session" => %{"username" => username, "password" => password}}) do
    case Accounts.authenticate_by_username_and_pass(username, password) do
      {:ok, user} ->
        conn
        |> Auth.login(user)
        |> put_flash(:info, "Welcome back, #{user.name}!")
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid username or password")
        |> render(:new)
    end
  end

  def delete(conn, _params) do
    conn
    |> Auth.logout()
    |> put_flash(:info, "You have been logged out")
    |> redirect(to: ~p"/")
  end
end
