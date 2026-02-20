# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Rumbl.Repo.insert!(%Rumbl.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Rumbl.Repo
alias Rumbl.Accounts
alias Rumbl.Multimedia
alias Rumbl.Multimedia.Category

IO.puts("Seeding database...")

# Create Categories
categories = ["Action", "Drama", "Comedy", "Romance", "Sci-Fi", "Documentary", "Educational", "Music"]

IO.puts("Creating categories...")
for name <- categories do
  case Repo.get_by(Category, name: name) do
    nil ->
      Repo.insert!(%Category{name: name})
      IO.puts("  Created category: #{name}")
    _ ->
      IO.puts("  Category already exists: #{name}")
  end
end

# Create Demo User
IO.puts("\nCreating demo user...")
demo_user = case Accounts.get_user_by(username: "demo") do
  nil ->
    {:ok, user} = Accounts.register_user(%{
      name: "Demo User",
      username: "demo",
      password: "demo123456"
    })
    IO.puts("  Created user: demo (password: demo123456)")
    user
  user ->
    IO.puts("  Demo user already exists")
    user
end

# Create some demo videos
IO.puts("\nCreating demo videos...")
demo_videos = [
  %{
    title: "Elixir in 100 Seconds",
    url: "https://www.youtube.com/watch?v=R7t7zca8SyM",
    description: "A quick introduction to the Elixir programming language.",
    category: "Educational"
  },
  %{
    title: "Phoenix LiveView Tutorial",
    url: "https://www.youtube.com/watch?v=MZvmYaFkNJI",
    description: "Learn how to build real-time applications with Phoenix LiveView.",
    category: "Educational"
  },
  %{
    title: "The Soul of Erlang and Elixir",
    url: "https://www.youtube.com/watch?v=JvBT4XBdoUE",
    description: "Sasa Juric explains the philosophy behind Erlang/OTP and Elixir.",
    category: "Documentary"
  }
]

for video_attrs <- demo_videos do
  category = Multimedia.get_category_by_name(video_attrs.category)

  attrs = %{
    title: video_attrs.title,
    url: video_attrs.url,
    description: video_attrs.description,
    category_id: category && category.id
  }

  # Check if video with same URL exists
  case Repo.get_by(Multimedia.Video, url: video_attrs.url) do
    nil ->
      {:ok, _video} = Multimedia.create_video(demo_user, attrs)
      IO.puts("  Created video: #{video_attrs.title}")
    _ ->
      IO.puts("  Video already exists: #{video_attrs.title}")
  end
end

IO.puts("\nSeeding complete!")
IO.puts("\nYou can log in with:")
IO.puts("  Username: demo")
IO.puts("  Password: demo123456")
