defmodule RumblWeb.WatchRoomLiveTest do
  use RumblWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Rumbl.Accounts
  alias Rumbl.Multimedia
  alias Rumbl.Repo
  alias Rumbl.WatchAlong
  alias Rumbl.WatchAlong.WatchRoom

  test "host can create a room from join page", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Room Host",
        "username" => "room_host_user",
        "password" => "roompass123"
      })

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/watch-rooms/join")

    view
    |> element("#watch-room-create-submit")
    |> render_click()

    room = Repo.get_by!(WatchRoom, host_id: user.id)
    assert_redirect(view, ~p"/watch-rooms/#{room.code}")
  end

  test "sidebar shows joined active room link", %{conn: conn} do
    {:ok, host} =
      Accounts.register_user(%{
        "name" => "Sidebar Host",
        "username" => "sidebar_host",
        "password" => "roompass123"
      })

    {:ok, viewer} =
      Accounts.register_user(%{
        "name" => "Sidebar Viewer",
        "username" => "sidebar_viewer",
        "password" => "roompass123"
      })

    {:ok, room} = WatchAlong.create_room(host)

    host_conn = init_test_session(conn, %{user_id: host.id})
    viewer_conn = init_test_session(conn, %{user_id: viewer.id})

    {:ok, _host_view, _html} = live(host_conn, ~p"/watch-rooms/#{room.code}")
    {:ok, viewer_view, _html} = live(viewer_conn, ~p"/watch-rooms/#{room.code}")

    assert has_element?(viewer_view, "#sidebar-joined-rooms")
    assert has_element?(viewer_view, "#sidebar-room-#{room.code}")
  end

  test "host can switch room video with same room code", %{conn: conn} do
    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Room Switch Host",
        "username" => "room_switch_host",
        "password" => "roompass123"
      })

    {:ok, video} =
      Multimedia.create_video(user, %{
        "title" => "Room Switch Video",
        "url" => "https://www.youtube.com/watch?v=R7t7zca8SyM",
        "description" => "host selected video"
      })

    {:ok, room} = WatchAlong.create_room(user)

    conn = init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/watch-rooms/#{room.code}")

    view
    |> form("#watch-room-video-form", room_video: %{"video_id" => Integer.to_string(video.id)})
    |> render_submit()

    assert_redirect(view, ~p"/watch/#{video}?#{[room_code: room.code]}")
  end

  test "joined viewer auto-redirects when host starts a video", %{conn: conn} do
    {:ok, host} =
      Accounts.register_user(%{
        "name" => "Auto Redirect Host",
        "username" => "auto_redirect_host",
        "password" => "roompass123"
      })

    {:ok, viewer} =
      Accounts.register_user(%{
        "name" => "Auto Redirect Viewer",
        "username" => "auto_redirect_viewer",
        "password" => "roompass123"
      })

    {:ok, video} =
      Multimedia.create_video(host, %{
        "title" => "Auto Redirect Video",
        "url" => "https://www.youtube.com/watch?v=R7t7zca8SyM",
        "description" => "video selected by host"
      })

    {:ok, room} = WatchAlong.create_room(host)

    host_conn = init_test_session(conn, %{user_id: host.id})
    viewer_conn = init_test_session(conn, %{user_id: viewer.id})

    {:ok, host_view, _html} = live(host_conn, ~p"/watch-rooms/#{room.code}")
    {:ok, viewer_view, _html} = live(viewer_conn, ~p"/watch-rooms/#{room.code}")

    host_view
    |> form("#watch-room-video-form", room_video: %{"video_id" => Integer.to_string(video.id)})
    |> render_submit()

    assert_redirect(host_view, ~p"/watch/#{video}?#{[room_code: room.code]}")
    assert_redirect(viewer_view, ~p"/watch/#{video}?#{[room_code: room.code]}")
  end

  test "room page shows user count", %{conn: conn} do
    {:ok, host} =
      Accounts.register_user(%{
        "name" => "Count Host",
        "username" => "count_host",
        "password" => "roompass123"
      })

    {:ok, viewer} =
      Accounts.register_user(%{
        "name" => "Count Viewer",
        "username" => "count_viewer",
        "password" => "roompass123"
      })

    {:ok, room} = WatchAlong.create_room(host)

    host_conn = init_test_session(conn, %{user_id: host.id})
    viewer_conn = init_test_session(conn, %{user_id: viewer.id})

    {:ok, host_view, _html} = live(host_conn, ~p"/watch-rooms/#{room.code}")
    {:ok, viewer_view, _html} = live(viewer_conn, ~p"/watch-rooms/#{room.code}")

    assert has_element?(host_view, "#watch-room-user-count", "Users in room: 2")
    assert has_element?(viewer_view, "#watch-room-user-count", "Users in room: 2")
  end

  test "open player uses latest room video on room page", %{conn: conn} do
    {:ok, host} =
      Accounts.register_user(%{
        "name" => "Latest Room Host",
        "username" => "latest_room_host",
        "password" => "roompass123"
      })

    {:ok, first_video} =
      Multimedia.create_video(host, %{
        "title" => "First Room Video",
        "url" => "https://www.youtube.com/watch?v=R7t7zca8SyM",
        "description" => "first room video"
      })

    {:ok, second_video} =
      Multimedia.create_video(host, %{
        "title" => "Second Room Video",
        "url" => "https://www.youtube.com/watch?v=aqz-KE-bpKQ",
        "description" => "second room video"
      })

    {:ok, room} = WatchAlong.create_room(host, first_video)

    conn = init_test_session(conn, %{user_id: host.id})
    {:ok, view, _html} = live(conn, ~p"/watch-rooms/#{room.code}")

    {:ok, _updated_room} = WatchAlong.set_room_video(room, second_video)

    view
    |> element("#watch-room-open-player-link")
    |> render_click()

    assert_redirect(view, ~p"/watch/#{second_video}?#{[room_code: room.code]}")
  end

  test "viewer can leave the room", %{conn: conn} do
    {:ok, host} =
      Accounts.register_user(%{
        "name" => "Leave Host",
        "username" => "leave_host",
        "password" => "roompass123"
      })

    {:ok, viewer} =
      Accounts.register_user(%{
        "name" => "Leave Viewer",
        "username" => "leave_viewer",
        "password" => "roompass123"
      })

    {:ok, room} = WatchAlong.create_room(host)

    host_conn = init_test_session(conn, %{user_id: host.id})
    viewer_conn = init_test_session(conn, %{user_id: viewer.id})

    {:ok, _host_view, _html} = live(host_conn, ~p"/watch-rooms/#{room.code}")
    {:ok, viewer_view, _html} = live(viewer_conn, ~p"/watch-rooms/#{room.code}")

    viewer_view
    |> element("#watch-room-leave-button")
    |> render_click()

    assert_redirect(viewer_view, ~p"/watch-rooms/join")
    room_after_leave = WatchAlong.get_room!(room.id)
    refute Enum.any?(room_after_leave.members, &(&1.user_id == viewer.id))
  end

  test "host can remove a viewer from room", %{conn: conn} do
    {:ok, host} =
      Accounts.register_user(%{
        "name" => "Remove Host",
        "username" => "remove_host",
        "password" => "roompass123"
      })

    {:ok, viewer} =
      Accounts.register_user(%{
        "name" => "Remove Viewer",
        "username" => "remove_viewer",
        "password" => "roompass123"
      })

    {:ok, room} = WatchAlong.create_room(host)

    host_conn = init_test_session(conn, %{user_id: host.id})
    viewer_conn = init_test_session(conn, %{user_id: viewer.id})

    {:ok, host_view, _html} = live(host_conn, ~p"/watch-rooms/#{room.code}")
    {:ok, viewer_view, _html} = live(viewer_conn, ~p"/watch-rooms/#{room.code}")

    host_view
    |> element("#watch-room-remove-member-#{viewer.id}")
    |> render_click()

    assert_redirect(viewer_view, ~p"/watch-rooms/join")
    assert has_element?(host_view, "#watch-room-user-count", "Users in room: 1")
  end

  test "host can delete the room and viewers are redirected", %{conn: conn} do
    {:ok, host} =
      Accounts.register_user(%{
        "name" => "Delete Room Host",
        "username" => "delete_room_host",
        "password" => "roompass123"
      })

    {:ok, viewer} =
      Accounts.register_user(%{
        "name" => "Delete Room Viewer",
        "username" => "delete_room_viewer",
        "password" => "roompass123"
      })

    {:ok, room} = WatchAlong.create_room(host)

    host_conn = init_test_session(conn, %{user_id: host.id})
    viewer_conn = init_test_session(conn, %{user_id: viewer.id})

    {:ok, host_view, _html} = live(host_conn, ~p"/watch-rooms/#{room.code}")
    {:ok, viewer_view, _html} = live(viewer_conn, ~p"/watch-rooms/#{room.code}")

    host_view
    |> element("#watch-room-delete-button")
    |> render_click()

    assert_redirect(host_view, ~p"/watch-rooms/join")
    assert_redirect(viewer_view, ~p"/watch-rooms/join")
    assert WatchAlong.get_room_by_code(room.code) == nil
  end
end
