defmodule RumblWeb.VideoHTML do
  use RumblWeb, :html

  alias Rumbl.Multimedia.Video

  embed_templates "video_html/*"

  @doc """
  Returns the YouTube video ID from the URL.
  """
  def youtube_id(video) do
    Video.youtube_id(video)
  end

  @doc """
  Formats time in milliseconds to mm:ss format.
  """
  def format_time(milliseconds) when is_integer(milliseconds) do
    total_seconds = div(milliseconds, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end

  def format_time(_), do: "0:00"
end
