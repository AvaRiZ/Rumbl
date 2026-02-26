defmodule Rumbl.Repo.Migrations.CreateWatchRoomMembers do
  use Ecto.Migration

  def change do
    create table(:watch_room_members) do
      add :role, :string, null: false, default: "viewer"
      add :watch_room_id, references(:watch_rooms, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create unique_index(:watch_room_members, [:watch_room_id, :user_id])
    create index(:watch_room_members, [:user_id])
  end
end
