defmodule Colcoord.Repo.Migrations.CreateSettings do
  use Ecto.Migration

  def change do
    create table(:settings) do
      add :selected_modes, :string, default: "[]"
      add :friends, :string, default: "[]"
      add :auto_join, :boolean, default: false, null: false
      add :last_game_found, :string

      timestamps(type: :utc_datetime)
    end
  end
end
