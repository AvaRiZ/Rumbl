defmodule Rumbl.WatchAlong.WatchRoomTest do
  use Rumbl.DataCase, async: true

  alias Rumbl.WatchAlong.WatchRoom

  test "changeset requires code, video_id, and host_id" do
    changeset = WatchRoom.changeset(%WatchRoom{}, %{})

    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).code
    assert "can't be blank" in errors_on(changeset).video_id
    assert "can't be blank" in errors_on(changeset).host_id
  end
end
