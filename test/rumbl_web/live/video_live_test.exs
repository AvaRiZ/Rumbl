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
end
