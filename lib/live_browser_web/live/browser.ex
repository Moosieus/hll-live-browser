defmodule LiveBrowserWeb.Browser do
  use LiveBrowserWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveBrowser.PubSub, "servers_info")
    end

    order = [{:players, :desc}]
    show_full = true
    show_empty = false

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> apply_user_settings(show_full, show_empty, order)

    socket = socket
    |> assign(:order, order)
    |> assign(:show_full, show_full)
    |> assign(:show_empty, show_empty)
    |> assign(:servers_info, servers_info)
    |> stream_configure(:servers_info, dom_id: fn {k, _v} -> "servers_info-#{k}" end)
    |> stream(:servers_info, servers_info)

    # |> assign(:servers_info, servers_info)

    {:ok, socket}
  end

  def handle_info(%{players: 0}, %{assigns: %{show_empty: false}} = socket) do
    {:noreply, socket}
  end

  def handle_info(%{players: 100}, %{assigns: %{show_full: false}} = socket) do
    {:noreply, socket}
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

  # bad, should be general!

  def handle_event("toggle", %{"by" => "show_full"}, socket) do
    show_full = !socket.assigns[:show_full]

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> apply_user_settings(show_full, socket.assigns.show_empty, socket.assigns.order)

    socket = socket
    |> assign(:show_full, show_full)
    |> assign(:servers_info, servers_info)
    |> stream(:servers_info, servers_info, reset: true)

    {:noreply, socket}
  end

  def handle_event("toggle", %{"by" => "show_empty"}, socket) do
    show_empty = !socket.assigns[:show_empty]

    servers_info = GenServer.call(Quester.Cache, :servers_info)
    |> apply_user_settings(socket.assigns.show_full, show_empty, socket.assigns.order)

    socket = socket
    |> assign(:show_empty, show_empty)
    |> assign(:servers_info, servers_info)
    |> stream(:servers_info, servers_info, reset: true)

    {:noreply, socket}
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

    servers_info = socket.assigns.servers_info
    |> apply_user_settings(socket.assigns.show_full, socket.assigns.show_empty, socket.assigns.order)

    socket = socket
    |> assign(:order, order)
    |> assign(:servers_info, servers_info)
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

  def apply_user_settings(servers, show_full, show_empty, order_opts) do
    servers
    |> sort_servers(order_opts)
    |> filter_servers(show_full, show_empty)
  end

  defp filter_servers(servers, show_full, show_empty) when is_boolean(show_full) and is_boolean(show_empty) do
    servers = case show_full do
      true -> Enum.filter(servers, fn {_addr, info} -> info.players !== 100 end)
      false -> servers
    end

    servers = case show_empty do
      true -> Enum.filter(servers, fn {_addr, info} -> info.players !== 0 end)
      false -> servers
    end

    servers
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
