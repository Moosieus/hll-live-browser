defmodule LiveBrowser.Quester do
  @moduledoc """
  A service context module (working name) for querying data from A2S game servers
  and publishing the data via the `"servers_info"` PubSub channel, and via `Quester.Cache`.
  """
  use Supervisor

  @type info_map :: %{
          required({:inet.ip4_address(), :inet.port_number()}) => A2S.Info.t()
        }

  def start_link(opts) do
    finch = finch_ref!(opts)

    config = %{
      finch: finch
    }

    Supervisor.start_link(__MODULE__, config, [])
  end

  ## Callbacks

  @impl true
  def init(config) do
    children = [
      {Registry, keys: :unique, name: :quester_registry},
      {LiveBrowser.Quester.DynamicSupervisor, name: LiveBrowser.Quester.DynamicSupervisor},
      LiveBrowser.Quester.UDP,
      {LiveBrowser.Quester.MasterList, finch: config.finch},
      LiveBrowser.Quester.Cache
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp finch_ref!(opts) do
    Keyword.get(opts, :finch) || raise(ArgumentError, "must provide a finch instance")
  end
end
