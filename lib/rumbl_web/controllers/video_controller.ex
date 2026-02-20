defmodule RumblWeb.VideoController do
  use RumblWeb, :controller

  alias Rumbl.Multimedia
  alias Rumbl.Multimedia.Video
  alias RumblWeb.Auth

  plug :require_authenticated_user when action in [:index, :new, :create, :edit, :update, :delete]

  defp require_authenticated_user(conn, _opts) do
    Auth.require_authenticated_user(conn, [])
  end

  def index(conn, _params) do
    videos = Multimedia.list_user_videos(conn.assigns.current_user)
    render(conn, :index, videos: videos)
  end

  def new(conn, _params) do
    changeset = Multimedia.change_video(%Video{})
    categories = Multimedia.category_options()
    render(conn, :new, changeset: changeset, categories: categories)
  end

  def create(conn, %{"video" => video_params}) do
    case Multimedia.create_video(conn.assigns.current_user, video_params) do
      {:ok, video} ->
        conn
        |> put_flash(:info, "Video created successfully.")
        |> redirect(to: ~p"/videos/#{video}")

      {:error, %Ecto.Changeset{} = changeset} ->
        categories = Multimedia.category_options()
        render(conn, :new, changeset: changeset, categories: categories)
    end
  end

  def show(conn, %{"id" => id}) do
    video = Multimedia.get_video!(id)
    render(conn, :show, video: video)
  end

  def edit(conn, %{"id" => id}) do
    video = Multimedia.get_user_video!(conn.assigns.current_user, id)
    changeset = Multimedia.change_video(video)
    categories = Multimedia.category_options()
    render(conn, :edit, video: video, changeset: changeset, categories: categories)
  end

  def update(conn, %{"id" => id, "video" => video_params}) do
    video = Multimedia.get_user_video!(conn.assigns.current_user, id)

    case Multimedia.update_video(video, video_params) do
      {:ok, video} ->
        conn
        |> put_flash(:info, "Video updated successfully.")
        |> redirect(to: ~p"/videos/#{video}")

      {:error, %Ecto.Changeset{} = changeset} ->
        categories = Multimedia.category_options()
        render(conn, :edit, video: video, changeset: changeset, categories: categories)
    end
  end

  def delete(conn, %{"id" => id}) do
    video = Multimedia.get_user_video!(conn.assigns.current_user, id)
    {:ok, _video} = Multimedia.delete_video(video)

    conn
    |> put_flash(:info, "Video deleted successfully.")
    |> redirect(to: ~p"/videos")
  end

  def watch(conn, %{"id" => id}) do
    video = Multimedia.get_video!(id)
    annotations = Multimedia.list_annotations(video)

    # Generate token for WebSocket auth
    user_token =
      if conn.assigns.current_user do
        Phoenix.Token.sign(conn, "user socket", conn.assigns.current_user.id)
      end

    render(conn, :watch, video: video, annotations: annotations, user_token: user_token)
  end
end
