defmodule RumblWeb.VideoLive do
  use RumblWeb, :live_view

  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Video

  embed_templates "video_live/*"

  @impl true
  def render(assigns), do: video_live(assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Videos")
     |> assign(:video, nil)
     |> assign(:annotations, [])
     |> assign(:categories, [])
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

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "My Videos")
    |> assign(:videos, Multimedia.list_user_videos(socket.assigns.current_user))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Add New Video")
    |> assign(:categories, Multimedia.category_options())
    |> assign(:form, to_form(Multimedia.change_video(%Video{})))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    video = Multimedia.get_video!(id)

    socket
    |> assign(:page_title, video.title)
    |> assign(:video, video)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    video = Multimedia.get_user_video!(socket.assigns.current_user, id)

    socket
    |> assign(:page_title, "Edit Video")
    |> assign(:video, video)
    |> assign(:categories, Multimedia.category_options())
    |> assign(:form, to_form(Multimedia.change_video(video)))
  end

  defp apply_action(socket, :watch, %{"id" => id}) do
    video = Multimedia.get_video!(id)

    user_token =
      if socket.assigns.current_user do
        Phoenix.Token.sign(RumblWeb.Endpoint, "user socket", socket.assigns.current_user.id)
      end

    socket
    |> assign(:page_title, "Watch #{video.title}")
    |> assign(:video, video)
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
         |> assign(:categories, Multimedia.category_options())
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
         |> assign(:categories, Multimedia.category_options())
         |> assign(:form, to_form(changeset))}
    end
  end

  defp youtube_id(video), do: Video.youtube_id(video)

  defp format_time(ms) do
    total_seconds = div(ms, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end
end
