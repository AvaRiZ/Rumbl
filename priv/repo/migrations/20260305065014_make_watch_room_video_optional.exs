defmodule Rumbl.Repo.Migrations.MakeWatchRoomVideoOptional do
  use Ecto.Migration

  def change do
    alter table(:watch_rooms) do
      modify :video_id, :bigint, null: true
    end
  end
end
