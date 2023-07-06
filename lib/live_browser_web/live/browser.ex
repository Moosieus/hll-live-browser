defmodule LiveBrowserWeb.Browser do
  use LiveBrowserWeb, :live_view

  @filter_defs %{
    hide_full: {:hide_full, &__MODULE__.filter_full/1},
    hide_empty: {:hide_empty, &__MODULE__.filter_empty/1}
  }

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveBrowser.PubSub, "servers_info")
    end

    order = [{:players, :desc}]
    filters = [@filter_defs.hide_empty, min: &(&1.players >= 30), max: &(&1.players <= 85)]

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> apply_user_settings(filters, order)

    socket = socket
    |> assign(:continents, [])
    |> assign(:order, order)
    |> assign(:min, 30)
    |> assign(:max, 85)
    |> assign(:filters, filters)
    |> assign(:servers_info, servers_info)
    |> stream_configure(:servers_info, dom_id: fn {k, _v} -> "servers_info-#{k}" end)
    |> stream(:servers_info, servers_info)

    {:ok, socket}
  end


  # update from PubSub
  def handle_info(info, %{assigns: %{servers_info: servers_info, order: order, filters: filters}} = socket) do

    cond do
      apply_filters({info.address, info}, filters) === false ->
        {:noreply, socket}

      order === [] ->
        # remove the existing item (if exists)
        socket = socket
        |> assign(:servers_info, List.keydelete(servers_info, info.address, 0))
        |> stream_delete_by_dom_id(:servers_info, "servers_info-#{info.address}")

        {:noreply, socket}
      true ->
        # remove the existing item (if exists)
        socket = socket
        |> assign(:servers_info, List.keydelete(servers_info, info.address, 0))
        |> stream_delete_by_dom_id(:servers_info, "servers_info-#{info.address}")

        # find the right index to insert the new item (edge case: lots of churn when everything's the same)
        index = case Enum.find_index(servers_info, &(compare_servers({info.address, info}, &1, order))) do
          nil -> Enum.count(servers_info)
          index -> index
        end

        # insert the new item
        socket = socket
        |> assign(:servers_info, List.insert_at(servers_info, index, {info.address, info}))
        |> stream_insert(:servers_info, {info.address, info}, at: index)

        {:noreply, socket}
    end
  end

  # set min/max players
  def handle_event("set_range", %{"min" => min_str, "max" => max_str}, %{assigns: %{filters: filters, order: order}} = socket) do

    min = case Integer.parse(min_str) do
      {min, _} -> min
      :error -> {:noreply, socket}
    end

    max = case Integer.parse(max_str) do
      {max, _} -> max
      :error -> {:noreply, socket}
    end

    filters = filters
    |> Keyword.replace(:min, &(&1.players >= min))
    |> Keyword.replace(:max, &(&1.players <= max))

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> apply_user_settings(filters, order)

    socket = socket
    |> assign(:min, min)
    |> assign(:max, max)
    |> assign(:filters, filters)
    |> assign(:servers_info, servers_info)
    |> stream(:servers_info, servers_info, reset: true)

    {:noreply, socket}
  end

  def handle_event("set_continents", %{"continents" => continents}, %{assigns: %{filters: filters, order: order}} = socket) do
    filters = Keyword.put(filters, :continents, &(&1.location["continent"]["code"] in continents))

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> apply_user_settings(filters, order)

    socket = socket
    |> assign(:continents, continents)
    |> assign(:filters, filters)
    |> assign(:servers_info, servers_info)
    |> stream(:servers_info, servers_info, reset: true)

    {:noreply, socket}
  end

  def handle_event("set_continents", _params, %{assigns: %{filters: filters, order: order}} = socket) do
    filters = Keyword.delete(filters, :continents)

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> apply_user_settings(filters, order)

    socket = socket
    |> assign(:continents, [])
    |> assign(:filters, filters)
    |> assign(:servers_info, servers_info)
    |> stream(:servers_info, servers_info, reset: true)

    {:noreply, socket}
  end

  # toggle filter
  def handle_event("toggle", %{"by" => filter}, %{assigns: %{filters: filters, order: order}} = socket) do
    filter = String.to_atom(filter)

    filters =
      case Keyword.get(filters, filter) do
        nil -> [Map.fetch!(@filter_defs, filter) | filters]
        _ -> Keyword.delete(filters, filter)
      end

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> apply_user_settings(filters, order)

    socket = socket
    |> assign(:filters, filters)
    |> assign(:servers_info, servers_info)
    |> stream(:servers_info, servers_info, reset: true)

    {:noreply, socket}
  end

  # toggle sort
  def handle_event("sort", %{"by" => field_str}, %{assigns: %{order: order, filters: filters, servers_info: servers_info}} = socket) do
    field = String.to_atom(field_str)

    direction = case List.keyfind(order, field, 0) do
      {_, direction} -> direction
      _ -> nil
    end

    order =
      case cycle_direction(direction) do
        nil  -> List.keydelete(order, field, 0)
        next -> List.keystore(order, field, 0, {field, next})
      end

    servers_info = apply_user_settings(servers_info, filters, order)

    socket = socket
    |> assign(:order, order)
    |> assign(:servers_info, servers_info)
    |> stream(:servers_info, servers_info, reset: true)

    {:noreply, socket}
  end

  def apply_user_settings(servers, filters, order_opts) do
    servers
    |> Enum.filter(&(apply_filters(&1, filters)))
    |> sort_servers(order_opts)
  end

  def apply_filters(_server, []), do: true
  def apply_filters({_addr, info}, filters) do
    do_apply_filters(info, filters)
  end

  def do_apply_filters(_info, []), do: true
  def do_apply_filters(info, [{_filter, filter_func} | rest]) do
    case filter_func.(info) do
      true -> do_apply_filters(info, rest)
      false -> false
    end
  end

  ## Filter definitions

  defp cycle_direction(order) do
    case order do
      :asc -> :desc
      :desc -> nil
      nil -> :asc
    end
  end

  def filter_full(%{players: 100}), do: false
  def filter_full(_), do: true

  def filter_empty(%{players: 0}), do: false
  def filter_empty(_), do: true

  ## Sorting

  defp sort_servers(servers, order_opts) do
    Enum.sort(servers, &(compare_servers(&1, &2, order_opts)))
  end

  defp compare_servers({_, info_i} = i, {_, info_ii} = ii, [{key, :asc} | next]) do
    cond do
      info_i[key] < info_ii[key] -> true
      info_i[key] > info_ii[key] -> false
      true -> compare_servers(i, ii, next)
    end
  end

  defp compare_servers({_, info_i} = i, {_, info_ii} = ii, [{key, :desc} | next]) do
    cond do
      info_i[key] > info_ii[key] -> true
      info_i[key] < info_ii[key] -> false
      true -> compare_servers(i, ii, next)
    end
  end

  defp compare_servers(_i, _ii, []), do: true

  ## Styles

  defp order_arrow_direction(order_opts, key) do
    case Keyword.get(order_opts, key) do
      :asc  -> "arrow-long-up"
      :desc -> "arrow-long-down"
      _ -> "arrows-up-down"
    end
  end

  defp map_full_name(name) do
    case name do
      "CAR_S_1944_P" -> "Carentan"
      "CT" -> "Carentan"
      "Foy_N" -> "Foy | Night"
      "Hill400" -> "Hill 400"
      "Hurtgen_N" -> "Hürtgen Forest"
      "Hurtgen" -> "Hürtgen Forest"
      "SME" -> "Sainte-Mère-Église"
      "Kursk_N" -> "Kursk | Night"
      "Omaha" -> "Omaha Beach"
      "PHL" -> "Purple Heart Lane"
      "PHL_N" -> "Purple Heart Lane | Night"
      "Stalin" -> "Stalingrad"
      "StMarie" -> "Sainte-Marie-du-Mont"
      "Utah" -> "Utah Beach"
      name -> name
    end
  end

  def continent_codes() do
    %{
      "AF" => "Africa",
      # "AN" => "Antarctica", # lol
      "AS" => "Asia",
      "EU" => "Europe",
      "NA" =>	"North america",
      "OC" =>	"Oceania",
      "SA" => "South America"
    }
  end

  def country_name(location) do
    case location["country"]["names"]["en"] do
      nil -> "unavailable"
      name -> name
    end
  end

  def region_name(location) do
    city = location["city"]["names"]["en"]

    subdivision =
      case location["subdivisions"] do
        nil -> nil
        [] -> nil
        [first | _rest] -> first["iso_code"]
      end

    [city, subdivision]
    |> Enum.filter(&(&1 !== nil))
    |> Enum.join(", ")
  end
end
