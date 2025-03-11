defmodule LiveBrowserWeb.Browser do
  require Logger
  use LiveBrowserWeb, :live_view

  import LiveBrowserWeb.CoreComponents

  alias LiveBrowser.Browser.Cache

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveBrowser.PubSub, "servers_info")
    end

    filters = [min: &(&1.a2s_players >= 30), max: &(&1.a2s_players <= 90)]
    order = [{:players, :desc}]

    servers_info =
      Cache.get_servers()
      |> apply_user_settings(filters, order)
      |> IO.inspect(label: "servers_info")

    socket =
      socket
      |> assign(:order, order)
      |> assign(:filters, filters)
      |> assign(:servers_info, servers_info)

    {:ok, socket}
  end

  # update from PubSub
  def handle_info({:update_info, server}, socket) do
    %{
      assigns: %{
        servers_info: server_list,
        order: order,
        filters: filters
      }
    } = socket

    case apply_filters({server.address, server}, filters) do
      true ->
        server_list = insert_server(server_list, server, order)
        socket = assign(socket, :servers_info, server_list)
        {:noreply, socket}

      false ->
        {:noreply, socket}
    end
  end

  def handle_info({:info_timeout, address}, socket) do
    %{
      assigns: %{servers_info: server_list}
    } = socket

    server_list = List.keydelete(server_list, address, 0)

    socket = assign(socket, :servers_info, server_list)
    {:noreply, socket}
  end

  # update filters
  def handle_info({:update_filters, filters}, socket) do
    %{
      assigns: %{order: order}
    } = socket

    servers_info =
      Cache.get_servers()
      |> apply_user_settings(filters, order)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:servers_info, servers_info)

    {:noreply, socket}
  end

  defp insert_server(server_list, server, []) do
    server_list = List.keydelete(server_list, server.address, 0)

    [{server.address, server} | server_list]
  end

  defp insert_server(server_list, server, order) do
    # remove existing server if present
    server_list = List.keydelete(server_list, server.address, 0)

    k_v = {server.address, server}

    # find the appropriate index for the new server (edge case: lots of churn when everything's the same)
    index =
      case Enum.find_index(server_list, &compare_servers(k_v, &1, order)) do
        nil -> Enum.count(server_list)
        index -> index
      end

    # return the new server list
    List.insert_at(server_list, index, k_v)
  end

  # toggle sort
  def handle_event(
        "sort",
        %{"by" => field_str},
        %{assigns: %{order: order, filters: filters, servers_info: servers_info}} = socket
      ) do
    field = String.to_atom(field_str)

    direction =
      case List.keyfind(order, field, 0) do
        {_, direction} -> direction
        _ -> nil
      end

    order =
      case cycle_order(direction) do
        nil -> List.keydelete(order, field, 0)
        next -> List.keystore(order, field, 0, {field, next})
      end

    servers_info = apply_user_settings(servers_info, filters, order)

    socket =
      socket
      |> assign(:order, order)
      |> assign(:servers_info, servers_info)

    {:noreply, socket}
  end

  def apply_user_settings(servers, filters, order_opts) do
    servers
    |> Enum.filter(&apply_filters(&1, filters))
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

  # ascending -> descending -> no order -> ...
  defp cycle_order(order) do
    case order do
      :asc -> :desc
      :desc -> nil
      nil -> :asc
    end
  end

  ## Sorting

  defp sort_servers(servers, order_opts) do
    Enum.sort(servers, &compare_servers(&1, &2, order_opts))
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

  ## Style Functions

  defp order_arrow_direction(order_opts, key) do
    case Keyword.get(order_opts, key) do
      :asc -> "hero-arrow-long-up"
      :desc -> "hero-arrow-long-down"
      _ -> "hero-arrows-up-down"
    end
  end
end
