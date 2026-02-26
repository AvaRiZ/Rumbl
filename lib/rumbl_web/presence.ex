defmodule RumblWeb.Presence do
  @moduledoc """
  Presence tracker for watch rooms.
  """
  use Phoenix.Presence,
    otp_app: :rumbl,
    pubsub_server: Rumbl.PubSub
end
