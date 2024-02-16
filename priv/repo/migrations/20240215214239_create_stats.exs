defmodule LiveBrowser.Repo.Migrations.CreateStats do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS timescaledb")

    create table("stats", primary_key: false) do
      add :timestamp, :utc_datetime, null: false
      add :name, :text, null: false
      add :ip_address, :text, null: false
      add :map, :text, null: false
      add :players, :integer, null: false
      add :max_players, :integer, null: false
    end

    execute("SELECT create_hypertable('stats', 'timestamp')")
  end

  def down do
    drop table("stats")

    execute("DROP EXTENSION IF EXISTS timescaledb")
  end
end
