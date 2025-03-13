defmodule LiveBrowser.Browser.FilterSet do
  @moduledoc """
  Represents a set of filters for the server browser.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias LiveBrowser.Browser.Server

  @region_options [
    {"Asia", :AS},
    {"Europe", :EU},
    {"North America", :NA},
    {"Oceania", :OC},
    {"South America", :SA}
    # {"Africa", :AF} (there are no servers currently in Africa)
  ]
  @region_values Enum.map(@region_options, fn {_text, val} -> val end)

  def region_options, do: @region_options

  schema "filter_set" do
    field :min_players, :integer, default: 30
    field :max_players, :integer, default: 100
    field :open_slots, :integer, default: 0
    field :with_queue?, :boolean, default: false
    field :regions, {:array, Ecto.Enum}, values: @region_values, default: []
    field :gamemode, {:array, Ecto.Enum}, values: Server.gamemode_values(), default: []
    field :time_of_day, {:array, Ecto.Enum}, values: Server.time_of_day_values(), default: []
    field :weather, {:array, Ecto.Enum}, values: Server.weather_values(), default: []
    field :official?, :boolean, default: false
    field :new_match?, :boolean, default: false
  end

  def new() do
    %__MODULE__{}
  end

  def changeset(filter_set, attrs) do
    filter_set
    |> cast(attrs, [
      :min_players,
      :max_players,
      :open_slots,
      :with_queue?,
      :regions,
      :gamemode,
      :time_of_day,
      :weather,
      :official?,
      :new_match?
    ])
    |> validate_min_lt_max()
    |> validate_number(:open_slots, greater_than_or_equal_to: 0)
  end

  defp validate_min_lt_max(changeset) do
    min = get_field(changeset, :min_players)
    max = get_field(changeset, :max_players)

    cond do
      min < max -> changeset
      true -> add_error(changeset, :min, "min players must be less than max")
    end
  end

  def to_filter_function(%__MODULE__{} = filter_set) do
    fn {_addr, %Server{} = server} ->
      [
        server.a2s_players >= filter_set.min_players,
        server.a2s_players <= filter_set.max_players,
        if(filter_set.regions != [], do: server.country_code in filter_set.regions),
        if(filter_set.gamemode != [], do: server.gamemode in filter_set.gamemode),
        if(filter_set.time_of_day != [], do: server.time_of_day in filter_set.time_of_day),
        if(filter_set.weather != [], do: server.weather in filter_set.weather),
        if(filter_set.official?, do: server.official?),
        if(filter_set.new_match?, do: server.new_match?)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.all?()
    end
  end
end
