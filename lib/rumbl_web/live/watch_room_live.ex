defmodule RumblWeb.WatchRoomLive do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia
  alias Rumbl.WatchAlong
  alias RumblWeb.Endpoint

  embed_templates "watch_room_live/*"

  @impl true
  def render(assigns), do: watch_room_live(assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:room_form, to_form(%{"code" => ""}, as: :room))
     |> assign(:room_video_form, to_form(%{"video_id" => ""}, as: :room_video))
     |> assign(:room_topic, nil)
     |> assign(:room, nil)
     |> assign(:room_user_count, 0)
     |> assign(:host_videos, [])
     |> assign(:host_video_options, [])
     |> assign(:can_manage_room?, false)
     |> assign(:page_title, "Join Watch Room")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("join_room", %{"room" => %{"code" => code}}, socket) do
    code = normalize_room_code(code)

    if code == "" do
      {:noreply, put_flash(socket, :error, "Enter a room code")}
    else
      {:noreply, push_navigate(socket, to: ~p"/watch-rooms/#{code}")}
    end
  end

  @impl true
  def handle_event("create_room", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, put_flash(socket, :error, "You must be logged in to create a room")}

      current_user ->
        case WatchAlong.create_room(current_user) do
          {:ok, room} ->
            {:noreply,
             socket
             |> put_flash(:info, "Room #{room.code} created. Choose a video to start.")
             |> push_navigate(to: ~p"/watch-rooms/#{room.code}")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, put_flash(socket, :error, "Failed to create room")}
        end
    end
  end

  @impl true
  def handle_event("select_video", %{"room_video" => %{"video_id" => video_id}}, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_user

    cond do
      is_nil(room) ->
        {:noreply, put_flash(socket, :error, "Room not found")}

      is_nil(current_user) or current_user.id != room.host_id ->
        {:noreply, put_flash(socket, :error, "Only the host can change the room video")}

      true ->
        with {:ok, selected_video_id} <- parse_video_id(video_id),
             %{} = video <- Enum.find(socket.assigns.host_videos, &(&1.id == selected_video_id)),
             {:ok, updated_room} <- WatchAlong.set_room_video(room, video) do
          room = WatchAlong.get_room!(updated_room.id)

          _ =
            Endpoint.broadcast(
              "watch_room:#{room.code}",
              "video_changed",
              room_video_payload(room, video)
            )

          _ =
            Phoenix.PubSub.broadcast(
              Rumbl.PubSub,
              room_topic(room.code),
              {:room_video_changed, room_video_payload(room, video)}
            )

          {:noreply,
           socket
           |> refresh_room_assigns(room)
           |> put_flash(:info, "Now playing #{video.title}")
           |> push_navigate(to: ~p"/watch/#{video}?#{[room_code: room.code]}")}
        else
          {:error, :invalid_video} ->
            {:noreply, put_flash(socket, :error, "Select a valid video")}

          nil ->
            {:noreply, put_flash(socket, :error, "Video is not available for this host")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, put_flash(socket, :error, "Failed to update room video")}
        end
    end
  end

  @impl true
  def handle_event("open_current_video", _params, socket) do
    case latest_room(socket) do
      nil ->
        {:noreply, put_flash(socket, :error, "Room not found")}

      %{video: nil} = room ->
        {:noreply,
         socket |> refresh_room_assigns(room) |> put_flash(:error, "No video selected yet")}

      %{video: video} = room ->
        {:noreply,
         socket
         |> refresh_room_assigns(room)
         |> push_navigate(to: ~p"/watch/#{video}?#{[room_code: room.code]}")}
    end
  end

  @impl true
  def handle_event("leave_room", _params, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_user

    cond do
      is_nil(room) ->
        {:noreply, put_flash(socket, :error, "Room not found")}

      is_nil(current_user) ->
        {:noreply, put_flash(socket, :error, "You must be logged in")}

      current_user.id == room.host_id ->
        {:noreply, put_flash(socket, :error, "Host cannot leave. Delete the room instead.")}

      true ->
        _ = WatchAlong.leave_room(room, current_user)
        _ = broadcast_room_members_changed(room.code)

        {:noreply,
         socket
         |> put_flash(:info, "You left room #{room.code}")
         |> push_navigate(to: ~p"/watch-rooms/join")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"user_id" => user_id}, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_user

    cond do
      is_nil(room) ->
        {:noreply, put_flash(socket, :error, "Room not found")}

      is_nil(current_user) or current_user.id != room.host_id ->
        {:noreply, put_flash(socket, :error, "Only the host can remove members")}

      true ->
        with {:ok, member_user_id} <- parse_user_id(user_id),
             :ok <- WatchAlong.remove_room_member(room, member_user_id) do
          _ = broadcast_room_members_changed(room.code)
          _ = broadcast_room_member_removed(room.code, member_user_id)

          {:noreply,
           socket
           |> refresh_room_assigns()
           |> put_flash(:info, "Member removed from room")}
        else
          {:error, :cannot_remove_host} ->
            {:noreply, put_flash(socket, :error, "Host cannot be removed")}

          {:error, :member_not_found} ->
            {:noreply, put_flash(socket, :error, "Member not found")}

          {:error, :invalid_member} ->
            {:noreply, put_flash(socket, :error, "Invalid member")}
        end
    end
  end

  @impl true
  def handle_event("delete_room", _params, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_user

    cond do
      is_nil(room) ->
        {:noreply, put_flash(socket, :error, "Room not found")}

      is_nil(current_user) or current_user.id != room.host_id ->
        {:noreply, put_flash(socket, :error, "Only the host can delete this room")}

      true ->
        case WatchAlong.delete_room(room) do
          {:ok, _deleted_room} ->
            _ = broadcast_room_deleted(room.code)

            {:noreply,
             socket
             |> put_flash(:info, "Room #{room.code} deleted")
             |> push_navigate(to: ~p"/watch-rooms/join")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, put_flash(socket, :error, "Failed to delete room")}
        end
    end
  end

  defp apply_action(socket, :join, _params) do
    socket
    |> assign(:page_title, "Join Watch Room")
    |> assign(:room_topic, nil)
    |> assign(:room, nil)
    |> assign(:room_user_count, 0)
    |> assign(:host_videos, [])
    |> assign(:host_video_options, [])
    |> assign(:can_manage_room?, false)
    |> assign(:room_video_form, to_form(%{"video_id" => ""}, as: :room_video))
  end

  defp apply_action(socket, :show, %{"code" => code}) do
    room_code = normalize_room_code(code)

    case WatchAlong.get_room_by_code(room_code) do
      nil ->
        socket
        |> put_flash(:error, "Room #{room_code} was not found")
        |> push_navigate(to: ~p"/watch-rooms/join")

      room ->
        case socket.assigns.current_user do
          nil ->
            socket
            |> put_flash(:error, "You must be logged in to join this room")
            |> push_navigate(to: ~p"/sessions/new")

          current_user ->
            role = if current_user.id == room.host_id, do: "host", else: "viewer"
            {:ok, _member} = WatchAlong.join_room(room, current_user, role)
            _ = broadcast_room_members_changed(room.code)

            room = WatchAlong.get_room!(room.id)

            host_videos =
              if(role == "host", do: Multimedia.list_user_videos(current_user), else: [])

            socket
            |> maybe_subscribe_to_room_topic(room.code)
            |> assign(:page_title, "Room #{room.code}")
            |> refresh_room_assigns(room)
            |> assign(:host_videos, host_videos)
            |> assign(:host_video_options, host_video_options(host_videos))
            |> assign(:can_manage_room?, role == "host")
        end
    end
  end

  @impl true
  def handle_info({:room_video_changed, %{video_slug: video_slug, room_code: room_code}}, socket) do
    room = socket.assigns.room
    current_user = socket.assigns.current_user

    cond do
      is_nil(room) ->
        {:noreply, socket}

      normalize_room_code(room_code) != room.code ->
        {:noreply, socket}

      true ->
        socket = refresh_room_assigns(socket)

        if not is_nil(current_user) and current_user.id == room.host_id do
          {:noreply, socket}
        else
          {:noreply,
           push_navigate(socket, to: ~p"/watch/#{video_slug}?#{[room_code: room.code]}")}
        end
    end
  end

  @impl true
  def handle_info({:room_members_changed, %{room_code: room_code}}, socket) do
    room = socket.assigns.room

    cond do
      is_nil(room) ->
        {:noreply, socket}

      normalize_room_code(room_code) != room.code ->
        {:noreply, socket}

      true ->
        {:noreply, refresh_room_assigns(socket)}
    end
  end

  @impl true
  def handle_info(
        {:room_member_removed, %{room_code: room_code, user_id: removed_user_id}},
        socket
      ) do
    room = socket.assigns.room
    current_user = socket.assigns.current_user

    cond do
      is_nil(room) ->
        {:noreply, socket}

      normalize_room_code(room_code) != room.code ->
        {:noreply, socket}

      is_nil(current_user) ->
        {:noreply, socket}

      current_user.id == removed_user_id ->
        {:noreply,
         socket
         |> put_flash(:error, "You were removed from room #{room.code}")
         |> push_navigate(to: ~p"/watch-rooms/join")}

      true ->
        {:noreply, refresh_room_assigns(socket)}
    end
  end

  @impl true
  def handle_info({:room_deleted, %{room_code: room_code}}, socket) do
    room = socket.assigns.room

    cond do
      is_nil(room) ->
        {:noreply, socket}

      normalize_room_code(room_code) != room.code ->
        {:noreply, socket}

      true ->
        {:noreply,
         socket
         |> put_flash(:error, "Room #{room.code} was deleted by the host")
         |> push_navigate(to: ~p"/watch-rooms/join")}
    end
  end

  defp normalize_room_code(code) do
    code
    |> to_string()
    |> String.trim()
    |> String.upcase()
  end

  defp parse_video_id(video_id) when is_binary(video_id) do
    case Integer.parse(video_id) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, :invalid_video}
    end
  end

  defp parse_video_id(_), do: {:error, :invalid_video}

  defp parse_user_id(user_id) when is_binary(user_id) do
    case Integer.parse(user_id) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, :invalid_member}
    end
  end

  defp parse_user_id(_), do: {:error, :invalid_member}

  defp host_video_options(videos) do
    Enum.map(videos, &{"#{&1.title} (#{&1.slug})", &1.id})
  end

  defp room_topic(room_code), do: "watch_room_live:#{room_code}"

  defp broadcast_room_members_changed(room_code) do
    Phoenix.PubSub.broadcast(
      Rumbl.PubSub,
      room_topic(room_code),
      {:room_members_changed, %{room_code: room_code}}
    )
  end

  defp broadcast_room_member_removed(room_code, user_id) do
    Phoenix.PubSub.broadcast(
      Rumbl.PubSub,
      room_topic(room_code),
      {:room_member_removed, %{room_code: room_code, user_id: user_id}}
    )
  end

  defp broadcast_room_deleted(room_code) do
    Phoenix.PubSub.broadcast(
      Rumbl.PubSub,
      room_topic(room_code),
      {:room_deleted, %{room_code: room_code}}
    )
  end

  defp room_video_payload(room, video) do
    %{
      room_code: room.code,
      video_id: video.id,
      video_slug: video.slug
    }
  end

  defp maybe_subscribe_to_room_topic(socket, room_code) do
    topic = room_topic(room_code)
    previous_topic = socket.assigns.room_topic

    if connected?(socket) do
      if previous_topic && previous_topic != topic do
        Phoenix.PubSub.unsubscribe(Rumbl.PubSub, previous_topic)
      end

      if previous_topic != topic do
        Phoenix.PubSub.subscribe(Rumbl.PubSub, topic)
      end
    end

    assign(socket, :room_topic, topic)
  end

  defp latest_room(socket) do
    case socket.assigns.room do
      nil -> nil
      room -> WatchAlong.get_room_by_code(room.code)
    end
  end

  defp refresh_room_assigns(socket), do: refresh_room_assigns(socket, latest_room(socket))

  defp refresh_room_assigns(socket, nil), do: socket

  defp refresh_room_assigns(socket, room) do
    selected_video_id = if(room.video_id, do: Integer.to_string(room.video_id), else: "")

    socket
    |> assign(:room, room)
    |> assign(:room_user_count, length(room.members || []))
    |> assign(:room_video_form, to_form(%{"video_id" => selected_video_id}, as: :room_video))
  end
end
