defmodule RumblWeb.VideoChannelTest do
  use RumblWeb.ChannelCase, async: true
  @endpoint RumblWeb.Endpoint

  alias Rumbl.Accounts
  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Annotation
  alias Rumbl.Repo
  alias RumblWeb.Endpoint
  alias RumblWeb.UserSocket

  test "adds annotation and broadcasts it" do
    user_suffix = rem(System.unique_integer([:positive]), 1_000_000)

    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Channel Annotator",
        "username" => "chan_#{user_suffix}",
        "password" => "annotatepass123"
      })

    {:ok, video} =
      Multimedia.create_video(user, %{
        "title" => "Channel Annotation Video #{System.unique_integer([:positive])}",
        "url" => "https://www.youtube.com/watch?v=R7t7zca8SyM",
        "description" => "channel annotation test"
      })

    token = Phoenix.Token.sign(Endpoint, "user socket", user.id)
    {:ok, socket} = connect(UserSocket, %{"token" => token})

    {:ok, %{annotations: []}, socket} =
      subscribe_and_join(socket, RumblWeb.VideoChannel, "video:#{video.id}")

    ref = push(socket, "new_annotation", %{"body" => "first note", "at" => 1200})

    assert_reply ref, :ok
    assert_broadcast "new_annotation", payload
    assert payload.body == "first note"
    assert payload.at == 1200
    assert payload.user.id == user.id
    assert payload.user.username == user.username

    assert Repo.get_by(Annotation,
             body: "first note",
             at: 1200,
             video_id: video.id,
             user_id: user.id
           )
  end
end
