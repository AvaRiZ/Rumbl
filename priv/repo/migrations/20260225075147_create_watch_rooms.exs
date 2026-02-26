defmodule Rumbl.Repo.Migrations.CreateWatchRooms do
  use Ecto.Migration

  def change do
    create table(:watch_rooms) do
      add :code, :string, null: false
      add :title, :string
      add :status, :string, null: false, default: "active"
      add :playing, :boolean, null: false, default: false
      add :current_ms, :integer, null: false, default: 0
      add :last_synced_at, :utc_datetime_usec
      add :video_id, references(:videos, on_delete: :delete_all), null: false
      add :host_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:watch_rooms, [:code])
    create index(:watch_rooms, [:video_id])
    create index(:watch_rooms, [:host_id])
  end
end
