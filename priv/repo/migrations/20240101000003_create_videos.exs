defmodule Rumbl.Repo.Migrations.CreateVideos do
  use Ecto.Migration

  def change do
    create table(:videos) do
      add :title, :string, null: false
      add :url, :string, null: false
      add :description, :text
      add :slug, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :nilify_all)

      timestamps()
    end

    create index(:videos, [:user_id])
    create index(:videos, [:category_id])
    create unique_index(:videos, [:slug])
  end
end
