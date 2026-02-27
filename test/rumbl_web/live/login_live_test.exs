defmodule RumblWeb.LoginLiveTest do
  @moduledoc """
  Tests for the login live view.
  """
  use RumblWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Rumbl.Accounts

  test "renders login form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sessions/new")

    assert has_element?(view, "#session-form")
    assert has_element?(view, "#log-in-button")
  end

  test "logs in user with valid credentials", %{conn: conn} do
    {:ok, _user} =
      Accounts.register_user(%{name: "Demo User", username: "demo", password: "secret"})

    {:ok, view, _html} = live(conn, "/sessions/new")

    result =
      view
      |> form("#session-form", session: %{"username" => "demo", "password" => "secret"})
      |> render_submit()

    assert result =~ "phx-trigger-action"
  end

  test "user logs in with blank password", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/sessions/new")

    response_html =
      view
      |> form("#session-form", session: %{"username" => "demo", "password" => ""})
      |> render_submit()

    # error message with id="session-error" is rendered
    assert response_html =~ "id=\"video-error\""
  end
end
