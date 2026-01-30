defmodule Mindset.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :role, :string
      add :content, :text

      timestamps()
    end
  end
end
