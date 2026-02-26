defmodule Rumbl.WatchAlong.WatchRoom do
  @moduledoc """
  The WatchRoom schema represents a virtual room where users can watch a video together in sync. It includes fields for the room code, title, status (active or ended), whether the video is currently playing, the current playback position in milliseconds, and timestamps for when the room was last synced. Each watch room is associated with a specific video and has a host user who created the room. Additionally, it has many members who have joined the room to watch the video together.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Rumbl.Accounts.User
  alias Rumbl.Multimedia.Video
  alias Rumbl.WatchAlong.WatchRoomMember

  schema "watch_rooms" do
    field :code, :string
    field :title, :string
    field :status, :string, default: "active"
    field :playing, :boolean, default: false
    field :current_ms, :integer, default: 0
    field :last_synced_at, :utc_datetime_usec

    belongs_to :video, Video
    belongs_to :host, User
    has_many :members, WatchRoomMember

    timestamps()
  end

  def changeset(watch_room, attrs) do
    watch_room
    |> cast(attrs, [
      :code,
      :title,
      :status,
      :playing,
      :current_ms,
      :last_synced_at,
      :video_id,
      :host_id
    ])
    |> validate_required([:code, :status, :video_id, :host_id])
    |> validate_inclusion(:status, ["active", "ended"])
    |> validate_number(:current_ms, greater_than_or_equal_to: 0)
    |> unique_constraint(:code)
    |> assoc_constraint(:video)
    |> assoc_constraint(:host)
  end
end
