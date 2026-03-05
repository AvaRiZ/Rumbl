defmodule RumblWeb.VideoLive do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Video
  alias Rumbl.WatchAlong
  alias RumblWeb.Endpoint

  embed_templates "video_live/*"

  @impl true
  def render(assigns), do: video_live(assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Videos")
     |> assign(:video, nil)
     |> assign(:room_code, nil)
     |> assign(:room_host_id, nil)
     |> assign(:room_playing, false)
     |> assign(:room_current_ms, 0)
     |> assign(:room, nil)
     |> assign(:host_videos, [])
     |> assign(:host_video_options, [])
     |> assign(:can_manage_room?, false)
     |> assign(:room_video_form, to_form(%{"video_id" => ""}, as: :room_video))
     |> assign(:annotations, [])
     |> assign(:categories, [])
     |> assign(:category_items, [])
     |> assign(:category_form, empty_category_form())
     |> assign(:form, to_form(Multimedia.change_video(%Video{})))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("save", %{"video" => video_params}, socket) do
    save_video(socket, socket.assigns.live_action, video_params)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    video = Multimedia.get_user_video!(socket.assigns.current_user, id)
    {:ok, _video} = Multimedia.delete_video(video)

    videos = Multimedia.list_user_videos(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:videos, videos)
     |> put_flash(:info, "Video deleted successfully.")}
  end

  @impl true
  def handle_event("create_category", %{"category" => category_params}, socket) do
    params = %{"name" => String.trim(category_params["name"] || "")}

    case Multimedia.create_category(params) do
      {:ok, _category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category added.")
         |> refresh_category_assigns()
         |> assign(:category_form, empty_category_form())}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> refresh_category_assigns()
         |> assign(:category_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    case Integer.parse(to_string(id)) do
      {category_id, ""} ->
        category = Multimedia.get_category!(category_id)
        {:ok, _category} = Multimedia.delete_category(category)

        {:noreply,
         socket
         |> put_flash(:info, "Category deleted.")
         |> refresh_category_assigns()
         |> maybe_reload_video_after_category_change()}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid category id.")}
    end
  end

  @impl true
  def handle_event("switch_room_video", %{"room_video" => %{"video_id" => video_id}}, socket) do
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
          payload = room_video_payload(room, video)

          _ = Endpoint.broadcast("watch_room:#{room.code}", "video_changed", payload)

          _ =
            Phoenix.PubSub.broadcast(
              Rumbl.PubSub,
              "watch_room_live:#{room.code}",
              {:room_video_changed, payload}
            )

          {:noreply,
           socket
           |> assign(:room, room)
           |> assign(
             :room_video_form,
             to_form(%{"video_id" => Integer.to_string(video.id)}, as: :room_video)
           )
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

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "My Videos")
    |> assign(:videos, Multimedia.list_user_videos(socket.assigns.current_user))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add New Video")
    |> refresh_category_assigns()
    |> assign(:category_form, empty_category_form())
    |> assign(:form, to_form(Multimedia.change_video(%Video{})))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    video = Multimedia.get_video!(id)

    socket
    |> assign(:page_title, video.title)
    |> assign(:video, video)
    |> assign(:room_code, nil)
    |> assign(:room_host_id, nil)
    |> assign(:room_playing, false)
    |> assign(:room_current_ms, 0)
    |> assign(:room, nil)
    |> assign(:host_videos, [])
    |> assign(:host_video_options, [])
    |> assign(:can_manage_room?, false)
    |> assign(:room_video_form, to_form(%{"video_id" => ""}, as: :room_video))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    video = Multimedia.get_user_video!(socket.assigns.current_user, id)

    socket
    |> assign(:page_title, "Edit Video")
    |> assign(:video, video)
    |> refresh_category_assigns()
    |> assign(:category_form, empty_category_form())
    |> assign(:form, to_form(Multimedia.change_video(video)))
  end

  defp apply_action(socket, :watch, %{"id" => id} = params) do
    video = Multimedia.get_video!(id)
    current_user = socket.assigns.current_user

    room_code =
      case params["room_code"] do
        nil -> nil
        code -> code |> to_string() |> String.trim() |> String.upcase()
      end

    room =
      case room_code do
        nil ->
          nil

        code ->
          case WatchAlong.get_room_by_code(code) do
            %{video_id: room_video_id} = room when room_video_id == video.id -> room
            _other -> nil
          end
      end

    can_manage_room? =
      not is_nil(room) and
        not is_nil(current_user) and
        current_user.id == room.host_id

    host_videos =
      if can_manage_room? do
        Multimedia.list_user_videos(current_user)
      else
        []
      end

    selected_video_id = if(room && room.video_id, do: Integer.to_string(room.video_id), else: "")

    user_token =
      if current_user do
        Phoenix.Token.sign(RumblWeb.Endpoint, "user socket", current_user.id)
      end

    socket
    |> assign(:page_title, "Watch #{video.title}")
    |> assign(:video, video)
    |> assign(:room_code, if(room, do: room.code, else: nil))
    |> assign(:room_host_id, if(room, do: room.host_id, else: nil))
    |> assign(:room_playing, if(room, do: room.playing, else: false))
    |> assign(:room_current_ms, if(room, do: room.current_ms, else: 0))
    |> assign(:room, room)
    |> assign(:host_videos, host_videos)
    |> assign(:host_video_options, host_video_options(host_videos))
    |> assign(:can_manage_room?, can_manage_room?)
    |> assign(:room_video_form, to_form(%{"video_id" => selected_video_id}, as: :room_video))
    |> assign(:annotations, Multimedia.list_annotations(video))
    |> assign(:user_token, user_token)
  end

  defp save_video(socket, :new, video_params) do
    case Multimedia.create_video(socket.assigns.current_user, video_params) do
      {:ok, video} ->
        {:noreply,
         socket
         |> put_flash(:info, "Video created successfully.")
         |> push_navigate(to: ~p"/videos/#{video}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> refresh_category_assigns()
         |> assign(:form, to_form(changeset))}
    end
  end

  defp save_video(socket, :edit, video_params) do
    video = socket.assigns.video

    case Multimedia.update_video(video, video_params) do
      {:ok, video} ->
        {:noreply,
         socket
         |> put_flash(:info, "Video updated successfully.")
         |> push_navigate(to: ~p"/videos/#{video}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> refresh_category_assigns()
         |> assign(:form, to_form(changeset))}
    end
  end

  defp refresh_category_assigns(socket) do
    category_items = Multimedia.list_categories()

    socket
    |> assign(:category_items, category_items)
    |> assign(:categories, Enum.map(category_items, &{&1.name, &1.id}))
  end

  defp maybe_reload_video_after_category_change(socket) do
    if socket.assigns.live_action == :edit do
      video = Multimedia.get_user_video!(socket.assigns.current_user, socket.assigns.video.slug)

      socket
      |> assign(:video, video)
      |> assign(:form, to_form(Multimedia.change_video(video)))
    else
      socket
    end
  end

  defp empty_category_form, do: to_form(%{"name" => ""}, as: :category)

  defp parse_video_id(video_id) when is_binary(video_id) do
    case Integer.parse(video_id) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, :invalid_video}
    end
  end

  defp parse_video_id(_), do: {:error, :invalid_video}

  defp host_video_options(videos) do
    Enum.map(videos, &{"#{&1.title} (#{&1.slug})", &1.id})
  end

  defp room_video_payload(room, video) do
    %{
      room_code: room.code,
      video_id: video.id,
      video_slug: video.slug
    }
  end

  defp youtube_id(video), do: Video.youtube_id(video)

  defp youtube_embed_url(video) do
    case youtube_id(video) do
      nil ->
        nil

      id ->
        origin = URI.encode_www_form(RumblWeb.Endpoint.url())
        "https://www.youtube.com/embed/#{id}?enablejsapi=1&origin=#{origin}&playsinline=1&rel=0"
    end
  end

  defp format_time(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end
end
