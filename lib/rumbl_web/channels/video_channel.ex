defmodule RumblWeb.VideoChannel do
  @moduledoc """
  A Phoenix Channel for handling real-time video annotations.
  """
  use RumblWeb, :channel

  alias Rumbl.{Accounts, Multimedia}

  @impl true
  def join("video:" <> video_id, _params, socket) do
    video_id = String.to_integer(video_id)
    video = Multimedia.get_video_by_id!(video_id)

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

  def handle_in("update_annotation", %{"id" => id, "body" => body}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    with {annotation_id, ""} <- Integer.parse(to_string(id)) do
      case Multimedia.update_annotation(user, annotation_id, %{"body" => body}) do
        {:ok, annotation} ->
          annotation = Rumbl.Repo.preload(annotation, :user)
          broadcast!(socket, "annotation_updated", annotation_json(annotation))
          {:reply, :ok, socket}

        {:error, changeset} ->
          {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
      end
    else
      _ -> {:reply, {:error, %{errors: ["Invalid annotation id"]}}, socket}
    end
  end

  def handle_in("delete_annotation", %{"id" => id}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)

    with {annotation_id, ""} <- Integer.parse(to_string(id)) do
      case Multimedia.delete_annotation(user, annotation_id) do
        {:ok, _annotation} ->
          broadcast!(socket, "annotation_deleted", %{id: annotation_id})
          {:reply, :ok, socket}

        {:error, _reason} ->
          {:reply, {:error, %{errors: ["Unable to delete annotation"]}}, socket}
      end
    else
      _ -> {:reply, {:error, %{errors: ["Invalid annotation id"]}}, socket}
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
