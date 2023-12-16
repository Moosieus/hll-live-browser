defmodule Quester.Cache do
  @moduledoc """
  Quester.Cache subscribes to `LiveBrowser.PubSub, "servers"` and stores all results in a map.
  This way when live views may render the last known good data upon mounting.
  """
  use GenServer

  alias Phoenix.PubSub

  ## Initialization

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

  ## API

  def get_servers(timeout \\ 5000) do
    GenServer.call(__MODULE__, :servers_info, timeout)
  end

  def get_server(address, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:get_info, address}, timeout)
  end

  ## Callbacks

  @impl true
  def handle_info({:update_info, info}, servers) do
    servers = List.keystore(servers, info.address, 0, {info.address, info})

    {:noreply, servers}
  end

  @impl true
  def handle_info({:info_timeout, address}, servers) do
    {:noreply, List.keydelete(servers, address, 0)}
  end

  @impl true
  # get info for all servers
  def handle_call(:servers_info, _from, servers) do
    {:reply, servers, servers}
  end

  @impl true
  # get info for a specific server
  def handle_call({:get_info, address}, _from, servers) do
    reply =
      case List.keyfind(servers, address, 0) do
        {_address, info} -> info
        nil -> nil
      end

    {:reply, reply, servers}
  end
end
