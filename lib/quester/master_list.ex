defmodule Quester.MasterList do
  @moduledoc """
  Queries Steam's master server list to discover what servers exist, and spin up Tenders under TendorVisor accordingly.

  Run on an interval of every N minutes. Keep servers in a map, and compare the old and new after each query.

  New entries should have Tenders started, and those that cease to exist should have be stopped.
  """
  use GenServer

  alias Quester.Tender
  alias Quester.DynamicSupervisor

  require Logger

  # Fully form request at compile time

  @appid Application.compile_env!(:live_browser, :appid)

  @limit Application.compile_env!(:live_browser, :limit)

  @interval Application.compile_env!(:live_browser, :master_list_interval)

  defmodule Server do
    @moduledoc """
    Represents a single server entry from the master list query. Only retains the fields we care about.
    """
    defstruct [
      :addr, :gameport, :name, :version, :players, :max_players, :map, :secure, :dedicated, :os, :gametype
    ]
  end

  ## API

  def start_link(default), do: GenServer.start_link(__MODULE__, default, [])

  ## Callbacks

  @impl true
  @spec init(any) :: {:ok, {term, map}}
  def init([name: _name, finch: finch]) do
    Logger.debug("initializing", Logger.metadata())

    Process.register(self(), __MODULE__)
    send(self(), :loop)
    {:ok, {finch, %{}}}
  end

  # Query the master list, starting a tender for each game server found.
  @impl true
  def handle_info(:loop, {finch, %{}}) do
    Logger.debug("initial loop", Logger.metadata())

    {:ok, current} = query_master_list(finch)

    Enum.each(current, fn {address, _server} ->
      DynamicSupervisor.start_child(address)
      Process.sleep(100) # bodge until I can figure out a way around {:error, :eagain} from the socket
    end)

    Process.send_after(self(), :loop, @interval)
    {:noreply, {finch, current}}
  end

  # Query the master list, starting a tender for each new game server and stopping tenders for ones that no longer present.
  def handle_info(:loop, {finch, old}) do
    Logger.debug("loop", Logger.metadata())

    import Map, only: [has_key?: 2]

    {:ok, current} = query_master_list(finch)

    Enum.each(old, fn {address, _server} ->
      case current |> has_key?(address) do
        true -> nil
        false ->
          Logger.debug(["closing tender", address: address], Logger.metadata())
          Tender.stop(address, :normal)
      end
    end)

    Enum.each(current, fn {address, _server} ->
      case old |> has_key?(address) do
        true -> nil
        false ->
          Logger.debug(["starting tender", address: address], Logger.metadata())
          DynamicSupervisor.start_child(address)
          Process.sleep(1)
      end
    end)

    Process.send_after(self(), :loop, @interval)
    {:noreply, current}
  end

  ## Functions

  @spec query_master_list(any()) :: {:ok, %{String => %Server{}}} | {:error, Exception.t()}
  defp query_master_list(finch) do

    steam_api_key = Application.fetch_env!(:live_browser, :steam_api_key) || raise "STEAM_API_KEY must be set in environment variables"

    request = Finch.build(
      :get, "http://api.steampowered.com/IGameServersService/GetServerList/v1/?" <> URI.encode_query(
        [key: steam_api_key, filter: "\\appid\\#{@appid}", limit: @limit]
      ),
      [{"Accept", "application/json"}]
    )

    with {:ok, %{status: 200, body: body}} <- Finch.request(request, finch),
         {:ok, servers} <- parse_server_list(body) do
      {:ok, key_by_address(servers)}
    end
  end

  defp parse_server_list(body) do
    {:ok, %{response: %{servers: servers}}} = Jason.decode(body, [keys: :atoms])

    servers = Enum.map(servers, fn server ->
      [ip, port] = String.split(server[:addr], ":")

      ip = ip
      |> String.split(".")
      |> Enum.map(fn i -> String.to_integer(i) end)
      |> List.to_tuple()

      port = String.to_integer(port)

      %{server | addr: {ip, port}}
    end)

    {:ok, servers}
  end

  defp key_by_address(servers) do
    Enum.reduce(servers, %{}, fn (server, acc) -> Map.put(acc, server.addr, server) end)
  end
end
