defmodule LiveBrowser.Browser do
  @moduledoc """
  Context functions for the server browser.
  """

  alias Phoenix.PubSub
  alias LiveBrowser.Browser.{Cache, Server}

  @doc """
  Determines the given server struct is significantly different from what was previously cached.

  A 'significant change' is any change relevant to players wanting to join
  servers (player count, map, etc).
  """
  def server_changed?(server = %Server{}) do
    cached = Cache.get_server(server.address)

    cond do
      # no previous entry
      is_nil(cached) ->
        true

      # significant field changed
      cached.name != server.name or cached.a2s_map != server.a2s_map or
          cached.a2s_players != server.a2s_players ->
        true

      # no changes
      true ->
        false
    end
  end

  @doc """
  Broadcasts new server info if it has a 'significant change' as defined by `server_changed?/1`.
  """
  def maybe_broadcast_server(%Server{} = server) do
    if server_changed?(server) do
      :ok = PubSub.broadcast(LiveBrowser.PubSub, "servers_info", {:update_info, server})
    end
  end
end
