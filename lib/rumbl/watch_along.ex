defmodule Rumbl.WatchAlong do
  @moduledoc """
  Watch-along context (rooms, membership, and playback state).
  """

  import Ecto.Query, warn: false

  alias Rumbl.Accounts.User
  alias Rumbl.Multimedia.Video
  alias Rumbl.Repo
  alias Rumbl.WatchAlong.{WatchRoom, WatchRoomMember}
  @unused_room_ttl_minutes 5

  @doc """
  Lists active watch rooms for a video.
  """
  def list_video_rooms(%Video{id: video_id}) do
    WatchRoom
    |> where([r], r.video_id == ^video_id and r.status == "active")
    |> order_by([r], desc: r.inserted_at)
    |> preload([:host])
    |> Repo.all()
  end

  @doc """
  Lists active rooms a user is hosting or has joined.
  """
  def list_user_active_rooms(%User{id: user_id}) do
    WatchRoom
    |> join(
      :left,
      [r],
      m in WatchRoomMember,
      on: m.watch_room_id == r.id and m.user_id == ^user_id
    )
    |> where([r, m], r.status == "active" and (r.host_id == ^user_id or not is_nil(m.id)))
    |> distinct([r, _m], r.id)
    |> order_by([r, _m], desc: r.updated_at)
    |> preload([:host, :video])
    |> Repo.all()
  end

  @doc """
  Gets a room by id and preloads host/video/members.
  """
  def get_room!(id) do
    WatchRoom
    |> Repo.get!(id)
    |> Repo.preload([:host, :video, members: [:user]])
  end

  @doc """
  Gets a room by public room code.
  """
  def get_room_by_code(code) when is_binary(code) do
    _ = cleanup_unused_or_inactive_rooms(@unused_room_ttl_minutes)
    normalized_code = String.upcase(String.trim(code))

    WatchRoom
    |> Repo.get_by(code: normalized_code)
    |> case do
      nil ->
        nil

      %WatchRoom{status: "active"} = room ->
        Repo.preload(room, [:host, :video, members: [:user]])

      room ->
        _ = Repo.delete(room)
        nil
    end
  end

  @doc """
  Creates a watch room for a host.
  """
  def create_room(host, attrs \\ %{})

  def create_room(%User{} = host, %Video{} = video), do: create_room(host, video, %{})

  def create_room(%User{} = host, attrs) when is_map(attrs) do
    _ = cleanup_unused_or_inactive_rooms(@unused_room_ttl_minutes)

    attrs =
      attrs
      |> Map.new()
      |> Map.put_new("code", generate_room_code())
      |> Map.put_new("status", "active")
      |> Map.put_new("playing", false)
      |> Map.put_new("current_ms", 0)
      |> Map.put("host_id", host.id)

    %WatchRoom{host_id: host.id}
    |> WatchRoom.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a watch room for a host and starts it on a specific video.
  """
  def create_room(%User{} = host, %Video{id: video_id}, attrs) when is_map(attrs) do
    attrs
    |> Map.new()
    |> Map.put("video_id", video_id)
    |> then(&create_room(host, &1))
  end

  @doc """
  Sets or switches the current video for a room.
  """
  def set_room_video(%WatchRoom{} = room, %Video{id: video_id}) do
    room
    |> WatchRoom.changeset(%{
      "video_id" => video_id,
      "playing" => false,
      "current_ms" => 0
    })
    |> Repo.update()
  end

  @doc """
  Deletes room codes that are inactive or stale and unused.
  """
  def cleanup_unused_or_inactive_rooms(max_age_minutes \\ @unused_room_ttl_minutes)

  def cleanup_unused_or_inactive_rooms(max_age_minutes)
      when is_integer(max_age_minutes) and max_age_minutes >= 0 do
    stale_before = NaiveDateTime.add(NaiveDateTime.utc_now(), -(max_age_minutes * 60), :second)

    inactive_ids =
      WatchRoom
      |> where([r], r.status != "active")
      |> select([r], r.id)
      |> Repo.all()

    stale_unused_ids =
      WatchRoom
      |> join(
        :left,
        [r],
        m in WatchRoomMember,
        on: m.watch_room_id == r.id and m.role == "viewer"
      )
      |> where([r, _m], r.status == "active" and r.updated_at < ^stale_before)
      |> group_by([r, _m], r.id)
      |> having([_r, m], count(m.id) == 0)
      |> select([r, _m], r.id)
      |> Repo.all()

    ids = Enum.uniq(inactive_ids ++ stale_unused_ids)

    if ids == [] do
      {0, nil}
    else
      WatchRoom
      |> where([r], r.id in ^ids)
      |> Repo.delete_all()
    end
  end

  @doc """
  Updates playback state for room synchronization.
  """
  def update_room_playback(%WatchRoom{} = room, attrs) do
    room
    |> WatchRoom.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks a room as ended.
  """
  def end_room(%WatchRoom{} = room) do
    room
    |> WatchRoom.changeset(%{"status" => "ended", "playing" => false})
    |> Repo.update()
  end

  @doc """
  Deletes a room.
  """
  def delete_room(%WatchRoom{} = room) do
    Repo.delete(room)
  end

  @doc """
  Joins a room as host/viewer membership.
  """
  def join_room(%WatchRoom{} = room, %User{} = user, role \\ "viewer") do
    %WatchRoomMember{}
    |> WatchRoomMember.changeset(%{
      "watch_room_id" => room.id,
      "user_id" => user.id,
      "role" => role
    })
    |> Repo.insert(
      on_conflict: [set: [role: role]],
      conflict_target: [:watch_room_id, :user_id]
    )
  end

  @doc """
  Removes a member from a room.
  """
  def leave_room(%WatchRoom{} = room, %User{id: user_id}) do
    WatchRoomMember
    |> where([m], m.watch_room_id == ^room.id and m.user_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Removes a non-host member by user id.
  """
  def remove_room_member(%WatchRoom{} = room, user_id)
      when is_integer(user_id) and user_id > 0 do
    if room.host_id == user_id do
      {:error, :cannot_remove_host}
    else
      {deleted_count, _} =
        WatchRoomMember
        |> where([m], m.watch_room_id == ^room.id and m.user_id == ^user_id)
        |> Repo.delete_all()

      if deleted_count > 0, do: :ok, else: {:error, :member_not_found}
    end
  end

  def remove_room_member(%WatchRoom{}, _user_id), do: {:error, :invalid_member}

  defp generate_room_code do
    4
    |> :crypto.strong_rand_bytes()
    |> Base.encode16()
  end
end
