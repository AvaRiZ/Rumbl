defmodule Rumbl.WatchAlong.WatchRoomMemberTest do
  use Rumbl.DataCase, async: true

  alias Rumbl.WatchAlong.WatchRoomMember

  test "changeset enforces role inclusion" do
    changeset =
      WatchRoomMember.changeset(%WatchRoomMember{}, %{
        "role" => "invalid",
        "watch_room_id" => 1,
        "user_id" => 1
      })

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).role
  end
end
