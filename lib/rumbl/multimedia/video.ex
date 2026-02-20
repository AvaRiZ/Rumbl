defmodule Rumbl.Multimedia.Video do
  use Ecto.Schema
  import Ecto.Changeset

  alias Rumbl.Accounts.User
  alias Rumbl.Multimedia.{Category, Annotation}

  @derive {Phoenix.Param, key: :slug}

  schema "videos" do
    field :title, :string
    field :url, :string
    field :description, :string
    field :slug, :string

    belongs_to :user, User
    belongs_to :category, Category
    has_many :annotations, Annotation

    timestamps()
  end

  def changeset(video, attrs) do
    video
    |> cast(attrs, [:title, :url, :description, :category_id])
    |> validate_required([:title, :url])
    |> validate_url(:url)
    |> assoc_constraint(:user)
    |> assoc_constraint(:category)
    |> slugify_title()
    |> unique_constraint(:slug)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
          []
        _ ->
          [{field, "must be a valid URL"}]
      end
    end)
  end

  defp slugify_title(%Ecto.Changeset{valid?: true, changes: %{title: title}} = changeset) do
    slug =
      title
      |> String.downcase()
      |> String.replace(~r/[^\w\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.trim("-")

    # Add random suffix for uniqueness
    slug = "#{slug}-#{:rand.uniform(9999)}"
    put_change(changeset, :slug, slug)
  end

  defp slugify_title(changeset), do: changeset

  @doc """
  Extracts YouTube video ID from URL.
  """
  def youtube_id(%__MODULE__{url: url}) do
    case Regex.run(~r{(?:youtube\.com/watch\?v=|youtu\.be/)([^&#?\s]+)}, url || "") do
      [_, id] -> id
      _ -> nil
    end
  end
end
