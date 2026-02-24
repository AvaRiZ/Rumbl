defmodule RumblWeb.LoginLiveTest do
  use RumblWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Rumbl.Accounts

  setup do
    {:ok, _user} =
      Accounts.register_user(%{
        "name" => "Login Test",
        "username" => "login_test_user",
        "password" => "loginpass123"
      })

    :ok
  end

  test "renders login form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions/new")

    assert has_element?(view, "#session-form")
    assert has_element?(view, "#log-in-button")
  end

  test "logs in and redirects home", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions/new")

    form_element =
      form(view, "#session-form",
        session: %{"username" => "login_test_user", "password" => "loginpass123"}
      )

    render_submit(form_element)
    conn = follow_trigger_action(form_element, conn)

    assert redirected_to(conn) == "/"
  end

  test "shows error on invalid credentials", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sessions/new")

    result =
      view
      |> form("#session-form",
        session: %{"username" => "login_test_user", "password" => "wrong_pass"}
      )
      |> render_submit()

    assert result =~ "Invalid username or password"
  end
end
