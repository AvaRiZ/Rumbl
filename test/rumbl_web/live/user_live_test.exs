defmodule RumblWeb.UserLiveTest do
  use RumblWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Rumbl.Accounts

  test "user profile page shows user's name and username", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Profile User",
        "username" => "profile",
        "password" => "profilepass123"
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/users/#{user}")

    assert has_element?(view, "#user-name", user.name)
    assert has_element?(view, "#user-username", "@#{user.username}")
  end
end
