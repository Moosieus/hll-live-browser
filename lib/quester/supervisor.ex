defmodule Quester.DynamicSupervisor do
  @moduledoc """
  Singleton dynamic supervisor for server tenders.
  """

  use DynamicSupervisor

  require Logger

  ## API

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec start_child(any) :: :ignore | {:error, any} | {:ok, pid} | {:ok, pid, any}
  def start_child(address) do
    DynamicSupervisor.start_child(__MODULE__, Quester.Tender.child_spec(address))
  end

  ## Callbacks

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
