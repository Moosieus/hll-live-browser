defmodule Quester.UDP do
  @moduledoc """
  GenServer wrapper over `:gen_udp`, responsible for sending packets to game-servers and routing received packets to the appropriate `A2S.Statem` process.
  """

  use GenServer

  @udp_port Application.compile_env!(:live_browser, :udp_port)

  ## API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [name: __MODULE__])
  end

  ## Callbacks

  @impl true
  def init(_config) do
    case :gen_udp.open(@udp_port, [:binary, active: true]) do
      {:error, reason} -> {:stop, reason}
      {:ok, socket} -> {:ok, socket}
    end
  end

  @doc """
  Forward received packets to the appropriate `A2S.Statem`.
  """
  @impl true
  def handle_info({:udp, _socket, ip, port, packet}, socket) do
    GenServer.cast(via_registry({ip, port}), packet)
    {:noreply, socket}
  end

  @doc """
  Send the given `msg` packet to the game server.
  """
  @impl true
  def handle_call({address, packet}, _from, socket) do
    with :ok <- :gen_udp.send(socket, address, packet) do
      {:reply, :ok, socket}
    else
      err -> {:reply, err, socket}
    end
  end

  ## Functions

  defp via_registry(name), do: {:via, Registry, {:quester_registry, name}}
end
