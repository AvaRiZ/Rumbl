defmodule RumblWeb.SessionController do
  use RumblWeb, :controller

  alias Rumbl.Accounts
  alias RumblWeb.Auth

  def create(conn, %{"session" => session_params}) do
    case Accounts.authenticate_by_username_and_pass(
           session_params["username"],
           session_params["password"]
         ) do
      {:ok, user} ->
        conn
        |> Auth.login(user)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: "/sessions/new")
    end
  end

  def delete(conn, _params) do
    conn
    |> Auth.logout()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: "/")
  end
end
