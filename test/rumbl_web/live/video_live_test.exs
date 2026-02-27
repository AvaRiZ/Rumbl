defmodule RumblWeb.VideoLiveTest do
  use RumblWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Rumbl.Accounts
  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Category
  alias Rumbl.Repo

  test "adds a video from the new page", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Video Test",
        "username" => "video_test_user",
        "password" => "videopass123"
      })

    category = Repo.insert!(%Category{name: "Testing"})

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/videos/new")

    video_title = "LiveView Video Test"

    _result =
      view
      |> form("#video-form",
        video: %{
          "title" => video_title,
          "url" => "https://www.youtube.com/watch?v=R7t7zca8SyM",
          "description" => "created from live test",
          "category_id" => category.id
        }
      )
      |> render_submit()

    assert Repo.get_by(Multimedia.Video, title: video_title)
  end

  test "try to add video without link", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Add Video Test",
        "username" => "add_video_test_user",
        "password" => "videopass123"
      })

    category = Repo.insert!(%Category{name: "Testing"})

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/videos/new")

    view
    |> form("#video-form",
      video: %{
        "title" => "Video without URL",
        "url" => "",
        "description" => "created from live test",
        "category_id" => category.id
      }
    )
    |> render_submit()

    assert has_element?(view, "#video_url.input-error")
  end

  test "add a new category", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Category Test",
        "username" => "category_test_user",
        "password" => "categorypass123"
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/videos/new")

    category_name = "Test Category"

    _result =
      view
      |> form("#new-video-category-form", category: %{"name" => category_name})
      |> render_submit()

    assert Repo.get_by(Category, name: category_name)
  end

  test "delete a category", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Delete Category",
        "username" => "delete_category_user",
        "password" => "deletepass123"
      })

    category = Repo.insert!(%Category{name: "Delete Test Category"})

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/videos/new")

    view
    |> element("#new-video-category-delete-#{category.id}")
    |> render_click()

    refute Repo.get(Category, category.id)
    refute has_element?(view, "#new-video-category-delete-#{category.id}")
  end

  test "create join code for watch room", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Watch Room Test",
        "username" => "watch_room_test_user",
        "password" => "videopass123"
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/watch-rooms/join")

    view
    |> form("#watch-room-join-form", room: %{"code" => "TESTCODE"})
    |> render_submit()

    assert_redirect(view, ~p"/watch-rooms/TESTCODE")
  end
end
