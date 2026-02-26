defmodule RumblWeb.ChannelCase do
  @moduledoc """
  Test case to be used by channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import RumblWeb.ChannelCase

      alias RumblWeb.Endpoint
    end
  end

  setup tags do
    Rumbl.DataCase.setup_sandbox(tags)
    :ok
  end
end
