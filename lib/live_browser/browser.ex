defmodule LiveBrowser.Browser do
  @moduledoc """
  Context functions for the server browser.
  """

  alias Phoenix.PubSub
  alias LiveBrowser.Browser.{Cache, Server, FilterSet}

  @doc """
  Determines the given server struct is significantly different from what was previously cached.

  A 'significant change' is any change relevant to players wanting to join
  servers (player count, map, etc).
  """
  def reporting_changed?(cached, %Server{} = new) do
    cond do
      # no previous entry
      is_nil(cached) ->
        true

      # significant field changed
      cached.name != new.name or cached.gs_map != new.gs_map or
          cached.a2s_players != new.a2s_players ->
        true

      # no changes
      true ->
        false
    end
  end

  defp maybe_set_map_times(nil, %Server{} = server), do: server

  defp maybe_set_map_times(%Server{} = cached, %Server{} = new) do
    now = DateTime.utc_now()

    map_changed_at =
      if map_changed?(cached, new), do: now, else: cached.map_changed_at

    new = %Server{new | map_changed_at: map_changed_at}

    new_match? =
      if not is_nil(new.map_changed_at) do
        DateTime.diff(now, new.map_changed_at, :second) <= 180
      else
        false
      end

    %Server{new | map_changed_at: map_changed_at, new_match?: new_match?}
  end

  defp map_changed?(%Server{} = cached, %Server{} = new) do
    cached = {cached.gs_map, cached.gamemode, cached.time_of_day, cached.weather}
    new = {new.gs_map, new.gamemode, new.time_of_day, new.weather}

    cached != new
  end

  @doc """
  Broadcasts new server info if it has a 'significant change' as defined by `reporting_changed?/1`.
  """
  def maybe_broadcast_server(%Server{} = server) do
    cached = Cache.get_server(server.address)

    # if reporting_changed?(cached, server) do
    server = maybe_set_map_times(cached, server)

    :ok = PubSub.broadcast(LiveBrowser.PubSub, "servers_info", {:server_info, server})
    # end
  end

  def change_filter_set(%FilterSet{} = filter_set, attrs \\ %{}) do
    FilterSet.changeset(filter_set, attrs)
  end
end
