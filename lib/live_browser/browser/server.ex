defmodule LiveBrowser.Browser.Server do
  @moduledoc """
  Represents the result of an A2S Query to a HLL server, with some additional
  data enrichment.
  """
  use Ecto.Schema

  # import Ecto.Changeset

  schema "server" do
    field :name, :string
    field :address, :string
    field :country, :string
    field :country_code, :string
    field :gamemode, Ecto.Enum, values: [:warfare, :offensive, :skirmish, :unknown]
    field :build_version, :integer
    field :a2s_players, :integer
    field :gs_players, :integer
    field :max_players, :integer
    field :official?, :boolean
    field :join_queue, :integer
    field :max_queue, :integer
    field :vip_queue, :integer
    field :max_vip, :integer
    field :crossplay?, :boolean
    field :offensive_attacker, :string
    field :a2s_map, :string
    field :gs_map, :string
    field :time_of_day, Ecto.Enum, values: [:dawn, :day, :dusk, :night, :unknown]
    field :weather, Ecto.Enum, values: [:clear, :overcast, :rain, :snow, :unknown]
    field :keywords, {:array, :string}
    field :last_changed, :utc_datetime
    field :gameport, :integer
    field :map_changed_at, :utc_datetime
    field :new_match?, :boolean, default: false
    field :visibility, Ecto.Enum, values: [:public, :private]
  end

  def new(%A2S.Info{} = info, address) do
    {country, country_code, region} = location(address)

    info =
      info
      |> Map.from_struct()
      |> Map.put(:name, String.trim_trailing(info.name))
      |> Map.put(:address, address_to_string(address))
      |> Map.put(:last_changed, DateTime.utc_now(:second))
      |> Map.put(:country, country)
      |> Map.put(:country_code, country_code)
      |> Map.put(:region, region)
      |> Map.put(:a2s_players, info.players)
      |> Map.put(:a2s_map, info.map)
      |> Map.delete(:players)
      |> Map.delete(:map)

    game_state = parse_game_state(info.keywords)

    data = Map.merge(info, game_state)

    struct(__MODULE__, data)
  end

  defp address_to_string({{part_i, part_ii, part_iii, part_iv}, port}) do
    "#{part_i}.#{part_ii}.#{part_iii}.#{part_iv}:#{port}"
  end

  # destructure location data here as :locus returns an outsized amount of data
  defp location(address) do
    case :locus.lookup(:city, address_to_ip_string(address)) do
      {:ok, location} ->
        {country(location), continent_code(location), region(location)}

      _ ->
        {:unknown, :unknown}
    end
  end

  defp address_to_ip_string({{part_i, part_ii, part_iii, part_iv}, _port}) do
    "#{part_i}.#{part_ii}.#{part_iii}.#{part_iv}"
  end

  defp country(location) when is_map(location) do
    case location["country"]["names"]["en"] do
      nil -> "unavailable"
      name -> name
    end
  end

  defp region(location) when is_map(location) do
    city = location["city"]["names"]["en"]

    subdivision =
      case location["subdivisions"] do
        [first | _rest] -> first["iso_code"]
        _ -> nil
      end

    [city, subdivision]
    |> Enum.filter(&(&1 !== nil))
    |> Enum.join(", ")
  end

  defp continent_code(location) when is_map(location) do
    case location["continent"]["code"] do
      nil -> :unknown
      code -> String.to_atom(code)
    end
  end

  defp parse_game_state(keywords) when is_binary(keywords) do
    keywords = String.split(keywords, ",")

    "GS:" <> game_state_b64 = Enum.find(keywords, &String.starts_with?(&1, "GS:"))

    game_state_bin = Base.decode64!(game_state_b64)

    <<
      _::4,
      gamemode::4,
      _::8,
      _::16,
      build_version::32,
      players::7,
      official::1,
      _::1,
      curr_vip::7,
      _::1,
      max_vip::7,
      _::2,
      cur_queue::3,
      max_queue::3,
      _::4,
      crossplay?::1,
      offensive_attacker::3,
      map::8,
      time_of_day::8,
      weather::8,
      _::binary
    >> = game_state_bin

    gamemode = parse_gamemode(gamemode)

    offensive_attacker =
      if gamemode == :Offensive, do: parse_offensive_attacker(offensive_attacker)

    %{
      gamemode: gamemode,
      build_version: build_version,
      gs_players: players,
      official?: official == 1,
      join_queue: cur_queue,
      max_queue: max_queue,
      vip_queue: curr_vip,
      max_vip: max_vip,
      crossplay?: crossplay? == 1,
      offensive_attacker: offensive_attacker,
      gs_map: parse_map(map),
      time_of_day: parse_time_of_day(time_of_day),
      weather: parse_weather(weather),
      keywords: keywords
    }
  end

  # Gamemode

  defp parse_gamemode(2), do: :Warfare
  defp parse_gamemode(3), do: :Offensive
  defp parse_gamemode(7), do: :Skirmish
  defp parse_gamemode(_), do: :Unknown

  @gamemode_options [{"Warfare", :Warfare}, {"Offensive", :Offensive}, {"Skirmish", :Skirmish}]
  @gamemode_values Enum.map(@gamemode_options, fn {_text, val} -> val end)

  def gamemode_options, do: @gamemode_options
  def gamemode_values, do: @gamemode_values

  defp parse_offensive_attacker(0), do: "GER"
  defp parse_offensive_attacker(1), do: "US"
  defp parse_offensive_attacker(2), do: "RUS"
  defp parse_offensive_attacker(3), do: "GB"
  defp parse_offensive_attacker(4), do: "DAK"
  defp parse_offensive_attacker(5), do: "B8A"
  defp parse_offensive_attacker(_), do: "Unknown"

  # Weather

  defp parse_weather(1), do: :Clear
  defp parse_weather(2), do: :Overcast
  defp parse_weather(3), do: :Rain
  defp parse_weather(4), do: :Snow
  defp parse_weather(_), do: :Unknown

  @weather_options [{"Clear", :Clear}, {"Overcast", :Overcast}, {"Rain", :Rain}, {"Snow", :Snow}]
  @weather_values Enum.map(@weather_options, fn {_text, val} -> val end)

  def weather_options, do: @weather_options
  def weather_values, do: @weather_values

  # Map

  defp parse_map(1), do: "Foy"
  defp parse_map(2), do: "St Marie du Mont"
  defp parse_map(3), do: "Hurtgen"
  defp parse_map(4), do: "Utah Beach"
  defp parse_map(5), do: "Omaha Beach"
  defp parse_map(6), do: "Sainte-Mère-Église"
  defp parse_map(7), do: "Purple Heart Lane"
  defp parse_map(8), do: "Hill 400"
  defp parse_map(9), do: "Carentan"
  defp parse_map(10), do: "Kursk"
  defp parse_map(11), do: "Stalingrad"
  defp parse_map(12), do: "Remagen"
  defp parse_map(13), do: "Kharkov"
  defp parse_map(14), do: "El Alamein"
  defp parse_map(15), do: "Driel"
  defp parse_map(16), do: "Mortain"
  defp parse_map(17), do: "Elsenborn"
  defp parse_map(_), do: "Unknown"

  # Time of day

  def parse_time_of_day(1), do: :Day
  def parse_time_of_day(2), do: :Night
  def parse_time_of_day(3), do: :Dusk
  def parse_time_of_day(5), do: :Dawn
  def parse_time_of_day(_), do: :Unknown

  @time_of_day_options [{"Dawn", :Dawn}, {"Day", :Day}, {"Dusk", :Dusk}, {"Night", :Night}]
  @time_of_day_values Enum.map(@time_of_day_options, fn {_text, val} -> val end)

  def time_of_day_options, do: @time_of_day_options
  def time_of_day_values, do: @time_of_day_values
end
