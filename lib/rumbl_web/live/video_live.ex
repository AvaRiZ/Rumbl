defmodule RumblWeb.VideoLive do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Video
  alias Rumbl.WatchAlong

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
     |> assign(:created_room_code, nil)
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
  def handle_event("create_code", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> assign(:created_room_code, nil)
         |> put_flash(:error, "You must be logged in to create a room code.")}

      current_user ->
        case WatchAlong.create_room(current_user, socket.assigns.video) do
          {:ok, room} ->
            {:noreply,
             socket
             |> assign(:created_room_code, room.code)
             |> put_flash(:info, "Room code #{room.code} created. Share it to invite others.")
             |> push_navigate(to: ~p"/watch/#{socket.assigns.video}?#{[room_code: room.code]}")}

          {:error, %Ecto.Changeset{}} ->
            {:noreply, put_flash(socket, :error, "Failed to create watch room code.")}
        end
    end
  end

  @impl true
  def handle_event("clear_code", _params, socket) do
    {:noreply, assign(socket, :created_room_code, nil)}
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
    |> assign(:created_room_code, nil)
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

    user_token =
      if socket.assigns.current_user do
        Phoenix.Token.sign(RumblWeb.Endpoint, "user socket", socket.assigns.current_user.id)
      end

    socket
    |> assign(:page_title, "Watch #{video.title}")
    |> assign(:video, video)
    |> assign(:room_code, if(room, do: room.code, else: nil))
    |> assign(:room_host_id, if(room, do: room.host_id, else: nil))
    |> assign(:room_playing, if(room, do: room.playing, else: false))
    |> assign(:room_current_ms, if(room, do: room.current_ms, else: 0))
    |> assign(:created_room_code, nil)
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
