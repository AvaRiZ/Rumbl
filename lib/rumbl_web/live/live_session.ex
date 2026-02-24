defmodule RumblWeb.LiveSession do
  @moduledoc """
  A module that defines the on_mount hooks for live sessions.

  This module is used to define the on_mount hooks for live sessions. The on_mount hooks are used to
  mount the current user and the flash messages for the live sessions.

  The on_mount hooks are defined in the `on_mount/0` function, which returns a list of tuples. Each tuple
  contains the module and the function to be called when the live session is mounted.

  The `on_mount/0` function is called in the `live_session/2` macro in the `RumblWeb.Router` module.
  """

  def on_mount do
    [
      {RumblWeb.LiveUserAuth, :mount_current_user},
      {RumblWeb.LiveFlash, :mount_flash}
    ]
  end
end
