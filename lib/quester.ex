defmodule Quester do
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
      {Quester.DynamicSupervisor, name: Quester.DynamicSupervisor},
      Quester.UDP,
      {Quester.MasterList, [name: Quester.MasterList, finch: config.finch]},
      Quester.Cache,
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp finch_ref!(opts) do
    Keyword.get(opts, :finch) || raise(ArgumentError, "must provide a finch instance")
  end
end
