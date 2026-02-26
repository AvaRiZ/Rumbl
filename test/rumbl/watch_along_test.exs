defmodule Rumbl.WatchAlongTest do
  use Rumbl.DataCase, async: true

  alias Rumbl.WatchAlong

  test "module is available for watch-along context work" do
    assert function_exported?(WatchAlong, :create_room, 3)
    assert function_exported?(WatchAlong, :join_room, 3)
  end
end
