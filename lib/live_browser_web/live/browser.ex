defmodule LiveBrowserWeb.Browser do
  use LiveBrowserWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveBrowser.PubSub, "servers_info")
    end

    order = [{:players, :desc}]

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> sort_servers(order)

    socket = socket
    |> assign(:show_full, true)
    |> assign(:show_empty, true)
    |> assign(:order, order)
    |> assign(:servers_info, servers_info)
    |> stream_configure(:servers_info, dom_id: fn {k, _v} -> "servers_info-#{k}" end)
    |> stream(:servers_info, servers_info)

    # |> assign(:servers_info, servers_info)

    {:ok, socket}
  end

  def handle_info(info, socket) do
    case socket.assigns.order do
      [] ->
        # don't care where it ends up
        socket
        |> assign(:servers_info, List.keystore(socket.assigns.servers_info, info.address, 0, {info.address, info}))
        |> stream_insert(:servers_info, {info.address, info})

        {:noreply, socket}
      order ->
        # remove the existing item (if exists)
        socket = socket
        |> assign(:servers_info, List.keydelete(socket.assigns.servers_info, info.address, 0))
        |> stream_delete_by_dom_id(:servers_info, "servers_info-#{info.address}")

        # find the right index to insert the new item (edge case: lots of churn when everything's the same)
        index = case Enum.find_index(socket.assigns.servers_info, &(compare_servers({info.address, info}, &1, order))) do
          nil -> Enum.count(socket.assigns.servers_info)
          index -> index
        end

        # insert the new item
        socket = socket
        |> assign(:servers_info, List.insert_at(socket.assigns.servers_info, index, {info.address, info}))
        |> stream_insert(:servers_info, {info.address, info}, at: index)

        {:noreply, socket}
    end
  end

  def handle_event("toggle", %{"by" => opt_str}, socket) do
    opt = String.to_atom(opt_str)

    {:noreply, assign(socket, opt, !socket.assign.opt)}
  end

  def handle_event("sort", %{"by" => field_str}, socket) do
    field = String.to_atom(field_str)

    direction = case List.keyfind(socket.assigns.order, field, 0) do
      {_, direction} -> direction
      _ -> nil
    end

    order = case cycle_direction(direction) do
      nil  -> List.keydelete(socket.assigns.order, field, 0)
      next -> List.keystore(socket.assigns.order, field, 0, {field, next})
    end

    socket = socket
    |> assign(:order, order)
    |> assign(:servers_info, sort_servers(socket.assigns.servers_info, order))
    |> stream(:servers_info, socket.assigns.servers_info, reset: true)

    {:noreply, socket}
  end

  defp cycle_direction(order) do
    case order do
      :asc -> :desc
      :desc -> nil
      nil -> :asc
    end
  end

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
end

# <a class="inline-block align-text-top text-blue-500 h-6" href={"steam://connect/#{address}"}>
#    <Heroicons.LiveView.icon name="arrow-top-right-on-square", type="outline", class="h-6 w-6" />
# </a>
