defmodule Rumbl.WatchAlong.WatchRoomMember do
  use Ecto.Schema
  import Ecto.Changeset

  alias Rumbl.Accounts.User
  alias Rumbl.WatchAlong.WatchRoom

  schema "watch_room_members" do
    field :role, :string, default: "viewer"

    belongs_to :watch_room, WatchRoom
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:role, :watch_room_id, :user_id])
    |> validate_required([:role, :watch_room_id, :user_id])
    |> validate_inclusion(:role, ["host", "viewer"])
    |> unique_constraint([:watch_room_id, :user_id])
    |> assoc_constraint(:watch_room)
    |> assoc_constraint(:user)
  end
end
