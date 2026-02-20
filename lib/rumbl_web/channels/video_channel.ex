defmodule RumblWeb.VideoChannel do
  use RumblWeb, :channel

  alias Rumbl.{Accounts, Multimedia}

  @impl true
  def join("video:" <> video_id, _params, socket) do
    video_id = String.to_integer(video_id)
    video = Multimedia.get_video!(video_id)

    annotations =
      video
      |> Multimedia.list_annotations()
      |> Enum.map(&annotation_json/1)

    {:ok, %{annotations: annotations}, assign(socket, :video_id, video_id)}
  end

  @impl true
  def handle_in("new_annotation", params, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    case Multimedia.annotate_video(user, socket.assigns.video_id, params) do
      {:ok, annotation} ->
        annotation = Rumbl.Repo.preload(annotation, :user)
        broadcast!(socket, "new_annotation", annotation_json(annotation))
        {:reply, :ok, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  defp annotation_json(annotation) do
    %{
      id: annotation.id,
      body: annotation.body,
      at: annotation.at,
      user: %{
        id: annotation.user.id,
        username: annotation.user.username
      }
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
