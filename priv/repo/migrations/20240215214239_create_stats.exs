defmodule LiveBrowser.Repo.Migrations.CreateStats do
  use Ecto.Migration

  def up do
    create table("stats", primary_key: false) do
      add :timestamp, :utc_datetime, null: false
      add :name, :text, null: false
      add :ip_address, :text, null: false
      add :map, :text, null: false
      add :players, :integer, null: false
      add :max_players, :integer, null: false
    end
  end

  def down do
    drop table("stats")
  end
end
