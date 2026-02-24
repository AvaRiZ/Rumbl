defmodule RumblWeb.RegistrationLiveTest do
  @moduledoc
  """
  Tests for the user registration live view.
  """

  use RumblWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Rumbl.Accounts

  test "renders registration form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/new")

    assert has_element?(view, "#user-form")
    assert has_element?(view, "#create-account-button")
  end

  test "registers a new user and redirects to login", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/new")

    result =
      view
      |> form("#user-form",
        user: %{
          "name" => "Register Test",
          "username" => "register_test_user",
          "password" => "registerpass123"
        }
      )
      |> render_submit()

    assert {:error, {:redirect, %{to: "/sessions/new"}}} = result
    assert Accounts.get_user_by(username: "register_test_user")
  end
end
