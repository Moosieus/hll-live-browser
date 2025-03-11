defmodule LiveBrowser.Browser.FilterSet do
  @moduledoc """
  Represents a set of filters for the server browser.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "filter_set" do
    field :min_players, :integer, default: 30
    field :max_players, :integer, default: 100
    field :open_slots, :integer, default: 0
    field :with_queue?, :boolean, default: false
    field :regions, {:array, Ecto.Enum}, values: [:AS, :EU, :NA, :OC, :SA], default: []
    field :gamemode, {:array, Ecto.Enum}, values: [:warfare, :offensive, :skirmish], default: []
    field :time_of_day, {:array, Ecto.Enum}, values: [:dawn, :day, :dusk, :night], default: []
    field :weather, {:array, Ecto.Enum}, values: [:clear, :overcast, :rain, :snow], default: []
  end

  def changeset(filter_set, attrs) do
    filter_set
    |> cast(attrs, [
      :min_players,
      :max_players,
      :open_slots,
      :with_queue,
      :regions,
      :gamemode,
      :time_of_day,
      :weather
    ])
    |> validate_min_lt_max()
    |> validate_number(:open_slots, greater_than_or_equal_to: 0)
  end

  defp validate_min_lt_max(changeset) do
    min = get_field(changeset, :min)
    max = get_field(changeset, :max)

    cond do
      min < max -> changeset
      true -> add_error(changeset, :min, "min players must be less than max")
    end
  end

  def to_filter_function(%__MODULE__{}) do
    fn server ->
      nil
    end
  end
end
