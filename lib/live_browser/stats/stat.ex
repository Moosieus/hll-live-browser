defmodule LiveBrowser.Stats.Stat do
  @moduledoc """
  Table for logging server metrics.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "stat" do
    field :timestamp, :utc_datetime
    field :name, :string
    field :ip_address, :string
    field :map, :string
    field :players, :integer
    field :max_players, :integer
  end

  @doc false
  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:timestamp, :name, :ip_address, :map, :players, :max_players])
    |> validate_required([:timestamp, :name, :ip_address, :map, :players, :max_players])
  end
end
