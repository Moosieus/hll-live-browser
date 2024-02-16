defmodule LiveBrowser.Stats.Persister do
  @moduledoc """
  Pulls data from Quester on semi-frequent interval for collecting general stats for servers.

  Should be able to update the interval at runtime.
  """

  use GenServer

  require Logger

  def init(_) do
    Logger.debug("initializing persister", Logger.metadata())

    send(self(), :loop)
    {:ok, %{}}
  end

  def handle_info(:loop, _) do
    # servers = Quester.Cache.get_servers()

    Process.sleep(query_interval())

    send(self(), :loop)
  end

  defp query_interval() do
    Application.get_env(:live_browser, :persistence_interval, 60)
  end
end
