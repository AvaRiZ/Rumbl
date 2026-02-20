defmodule Rumbl.Repo.Migrations.CreateAnnotations do
  use Ecto.Migration

  def change do
    create table(:annotations) do
      add :body, :string, null: false
      add :at, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :video_id, references(:videos, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:annotations, [:user_id])
    create index(:annotations, [:video_id])
  end
end
