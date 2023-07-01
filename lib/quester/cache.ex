defmodule Quester.Cache do
  @moduledoc """
  Quester.Cache subscribes to `LiveBrowser.PubSub, "servers"` and stores all results in a map.
  This way when live views may render the last known good data upon mounting.
  """
  use GenServer

  alias Phoenix.PubSub

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl true
  @spec init(any) :: {:ok, list()}
  def init(_state) do
    Process.register(self(), __MODULE__)

    :ok = PubSub.subscribe(LiveBrowser.PubSub, "servers_info")

    {:ok, []}
  end

  @impl true
  def handle_info(info, servers) do
    # {:noreply, Map.put(servers, info.address, info)}
    servers = servers
    |> List.keystore(info.address, 0, {info.address, info})

    {:noreply, servers}
  end

  @impl true
  def handle_call(:servers_info, _from, servers) do
    {:reply, servers, servers}
  end

  @impl true
  def handle_call({:get_info, address}, _from, servers) do

    reply = case List.keyfind(servers, address, 0) do
      {_address, info} -> info
      nil -> nil
    end

    {:reply, reply, servers}
  end
end
