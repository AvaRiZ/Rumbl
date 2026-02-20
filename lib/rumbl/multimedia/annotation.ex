defmodule Rumbl.Multimedia.Annotation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Rumbl.Accounts.User
  alias Rumbl.Multimedia.Video

  schema "annotations" do
    field :body, :string
    field :at, :integer  # Time in milliseconds

    belongs_to :user, User
    belongs_to :video, Video

    timestamps()
  end

  def changeset(annotation, attrs) do
    annotation
    |> cast(attrs, [:body, :at])
    |> validate_required([:body, :at])
    |> validate_number(:at, greater_than_or_equal_to: 0)
  end
end
