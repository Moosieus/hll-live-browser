defmodule LiveBrowserWeb.Browser do
  require Logger
  use LiveBrowserWeb, :live_view

  import LiveBrowserWeb.CoreComponents

  alias LiveBrowser.Browser.{FilterSet, Cache}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LiveBrowser.PubSub, "servers_info")
    end

    filter_set = FilterSet.new()
    filter_func = FilterSet.to_filter_function(filter_set)

    order = [{:a2s_players, :desc}]

    servers_info =
      Cache.get_servers()
      |> apply_user_settings(filter_func, order)

    socket =
      socket
      |> assign(:order, order)
      |> assign(:filter_set, filter_set)
      |> assign(:filter_func, filter_func)
      |> assign(:servers_info, servers_info)

    {:ok, socket}
  end

  # update from PubSub
  def handle_info({:server_info, server}, socket) do
    %{
      assigns: %{
        servers_info: server_list,
        order: order,
        filter_func: filter_func
      }
    } = socket

    case filter_func.({server.address, server}) do
      true ->
        server_list = insert_server(server_list, server, order)
        socket = assign(socket, :servers_info, server_list)
        {:noreply, socket}

      false ->
        {:noreply, socket}
    end
  end

  def handle_info({:filter_set, filter_set}, socket) do
    %{
      assigns: %{order: order}
    } = socket

    filter_func = FilterSet.to_filter_function(filter_set)

    servers_info =
      Cache.get_servers()
      |> apply_user_settings(filter_func, order)

    socket =
      socket
      |> assign(:filter_set, filter_set)
      |> assign(:filter_func, filter_func)
      |> assign(:servers_info, servers_info)

    {:noreply, socket}
  end

  def handle_info({:info_timeout, address}, socket) do
    %{
      assigns: %{servers_info: server_list}
    } = socket

    server_list = List.keydelete(server_list, address, 0)

    socket = assign(socket, :servers_info, server_list)
    {:noreply, socket}
  end

  # no ordering imposed (chaos)
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
  def handle_event("sort", %{"by" => field_str}, socket) do
    %{
      assigns: %{order: order, servers_info: servers_info}
    } = socket

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

    servers_info = sort_servers(servers_info, order)

    socket =
      socket
      |> assign(:order, order)
      |> assign(:servers_info, servers_info)

    {:noreply, socket}
  end

  def apply_user_settings(servers, filter_func, order_opts) do
    servers
    |> Enum.filter(filter_func)
    |> sort_servers(order_opts)
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
      get_in(info_i, [Access.key!(key)]) < get_in(info_ii, [Access.key!(key)]) -> true
      get_in(info_i, [Access.key!(key)]) > get_in(info_ii, [Access.key!(key)]) -> false
      true -> compare_servers(i, ii, next)
    end
  end

  defp compare_servers({_, info_i} = i, {_, info_ii} = ii, [{key, :desc} | next]) do
    cond do
      get_in(info_i, [Access.key!(key)]) > get_in(info_ii, [Access.key!(key)]) -> true
      get_in(info_i, [Access.key!(key)]) < get_in(info_ii, [Access.key!(key)]) -> false
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
