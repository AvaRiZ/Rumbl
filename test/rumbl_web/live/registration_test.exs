defmodule RumblWeb.Live.RegistrationTest do
  @moduledoc """
  Tests for the user registration live view.
  """

  use RumblWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders registration form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/users/new")

    assert has_element?(view, "#user-form")
    assert has_element?(view, "#create-account-button")
  end

  test "registers user with valid data", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/users/new")

    redirect_result =
      view
      |> form("#user-form",
        user: %{"name" => "Test User", "username" => "testuser", "password" => "password123"}
      )
      |> render_submit()

    assert {:error, {:redirect, %{to: "/sessions/new"}}} = redirect_result
  end

  test "registration fails with invalid data", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/users/new")

    _response_html =
      view
      |> form("#user-form", user: %{"name" => "test", "username" => "test", "password" => ""})
      |> render_submit()

    assert has_element?(view, "#user_password.input-error")
  end
end
