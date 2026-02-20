defmodule Rumbl.Multimedia do
  @moduledoc """
  The Multimedia context - handles videos, categories, and annotations.
  """

  import Ecto.Query, warn: false
  alias Rumbl.Repo
  alias Rumbl.Accounts.User
  alias Rumbl.Multimedia.{Video, Category, Annotation}

  # ============================================================================
  # Videos
  # ============================================================================

  @doc """
  Returns all videos.
  """
  def list_videos do
    Video
    |> Repo.all()
    |> Repo.preload([:user, :category])
  end

  @doc """
  Returns videos for a specific user.
  """
  def list_user_videos(%User{} = user) do
    Video
    |> user_videos_query(user)
    |> Repo.all()
    |> Repo.preload([:category])
  end

  @doc """
  Gets a single video by slug.
  """
  def get_video!(slug) when is_binary(slug) do
    Video
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:user, :category])
  end

  @doc """
  Gets a user's video by slug.
  """
  def get_user_video!(%User{} = user, slug) when is_binary(slug) do
    Video
    |> user_videos_query(user)
    |> where([v], v.slug == ^slug)
    |> Repo.one!()
  end

  @doc """
  Creates a video for a user.
  """
  def create_video(%User{} = user, attrs \\ %{}) do
    %Video{}
    |> Video.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  @doc """
  Updates a video.
  """
  def update_video(%Video{} = video, attrs) do
    video
    |> Video.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a video.
  """
  def delete_video(%Video{} = video) do
    Repo.delete(video)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking video changes.
  """
  def change_video(%Video{} = video, attrs \\ %{}) do
    Video.changeset(video, attrs)
  end

  defp user_videos_query(query, %User{id: user_id}) do
    from v in query, where: v.user_id == ^user_id
  end

  # ============================================================================
  # Categories
  # ============================================================================

  @doc """
  Returns all categories.
  """
  def list_categories do
    Category
    |> order_by([c], c.name)
    |> Repo.all()
  end

  @doc """
  Returns category options for forms.
  """
  def category_options do
    list_categories()
    |> Enum.map(&{&1.name, &1.id})
  end

  @doc """
  Gets a category by name.
  """
  def get_category_by_name(name) do
    Repo.get_by(Category, name: name)
  end

  @doc """
  Creates a category.
  """
  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  # ============================================================================
  # Annotations
  # ============================================================================

  @doc """
  Lists annotations for a video.
  """
  def list_annotations(%Video{} = video) do
    Annotation
    |> where([a], a.video_id == ^video.id)
    |> order_by([a], asc: a.at)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Creates an annotation for a video.
  """
  def annotate_video(%User{id: user_id}, video_id, attrs) do
    %Annotation{user_id: user_id, video_id: video_id}
    |> Annotation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes an annotation.
  """
  def delete_annotation(%Annotation{} = annotation) do
    Repo.delete(annotation)
  end
end
