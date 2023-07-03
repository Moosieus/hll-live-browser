defmodule Quester.Tender do
  @moduledoc """
  Queries a server over A2S every N seconds. For the time being each tender will just store the latest reply and return it on call()
  """

  require Logger

  alias Phoenix.PubSub

  @type init_args() :: {:inet.ip_address(), :inet.port_number()}

  @behaviour :gen_statem

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  @interval Application.compile_env!(:live_browser, :tender_interval)

  ## API

  @spec start_link(binary) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(address) do
    :gen_statem.start_link(via_registry(address), __MODULE__, address, [timeout: 10 * 1000])
  end

  @spec stop({:inet.ip_address(), :inet.port_number()}, any) :: :ok
  def stop(address, reason) do
    address |> via_registry |> GenServer.stop(reason)
  end

  @spec child_spec(init_args) :: Supervisor.child_spec()
  def child_spec(address) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [address]},
      restart: :temporary
    }
  end

  ## Callbacks

  @impl :gen_statem
  def init(address) do
    Logger.metadata([address: address])

    # send self a message

    :ok = GenServer.call(Quester.UDP, {address, A2S.challenge_request(:info)})
    {:ok, :await_challenge, {address, Time.utc_now}, recv_timeout()}
  end

  @impl :gen_statem
  def handle_event(:cast, packet, :await_challenge, {address, last_sent} = data) do
    case A2S.parse_challenge(packet) do
      {:challenge, challenge} ->
        # Logger.debug("got challenge", Logger.metadata())
        :ok = GenServer.call(Quester.UDP, {address, A2S.sign_challenge(:info, challenge)})
        {:next_state, :await_response, data, recv_timeout()}

      {:immediate, msg} ->
        # Logger.debug("got immediate", Logger.metadata())
        report_and_next(msg, data)

      {:multipacket, part} ->
        # Logger.debug("got multipacket", Logger.metadata())
        {:next_state, :collect_multipacket, {address, last_sent, [part]}, recv_timeout()}
    end
  end

  @impl :gen_statem
  def handle_event(:cast, packet, :await_response, {address, last_sent} = data) do
    case A2S.parse_response(packet) do
      {:info, _info} = msg ->
        report_and_next(msg, data)

      {:multipacket, {header, _body} = part} ->
        {:next_state, :collect_multipacket, {address, last_sent, header.total, [part]}, recv_timeout()}
    end
  end

  @impl :gen_statem
  def handle_event(:cast, packet, :collect_multipacket, {address, last_sent, total, parts}) do
    {:multipacket, part} = A2S.parse_response(packet)
    parts = [part | parts]

    if Enum.count(parts) === total do
      parts
      |> A2S.parse_multipacket_response()
      |> report_and_next({address, last_sent})
    else
      {:next_state, :collect_multipacket, {address, last_sent, total, parts}, recv_timeout()}
    end
  end

  ## Timeout

  def handle_event(:state_timeout, :recv_timeout, state, data) do
    IO.inspect([:timeout, {state, data}, Time.utc_now()])
    {:stop, {:timeout, {state, data}}} # stop and don't reset
  end

  defp recv_timeout() do
    {:state_timeout, 3000, :recv_timeout}
  end

  ## Functions

  defp report_and_next({:info, info}, {address, last_sent}) do
    info = info
    |> Map.from_struct()
    |> Map.put(:address, address_to_string(address))
    |> Map.put(:last_changed, Time.truncate(Time.utc_now(), :second))

    location =
      case :locus.lookup(:city, address_to_ip_string(address)) do
        {:ok, location} ->
          location
        :not_found ->
          :unknown
        {:error, reason} ->
          # add a log here!
          :unknown
      end

    info = Map.put(info, :location, location)

    if changed?(info) do
      :ok = PubSub.broadcast(LiveBrowser.PubSub, "servers_info", info)
    end

    sleep(last_sent)
    :ok = GenServer.call(Quester.UDP, {address, A2S.challenge_request(:info)})
    {:next_state, :await_challenge, {address, Time.utc_now}, recv_timeout()}
  end

  defp changed?(info) do
    old = GenServer.call(Quester.Cache, {:get_info, info.address})

    cond do
      # no previous entry
      old === nil -> true
      # significant field changed
      (old.name !== info.name) or (old.map !== info.map) or (old.players !== info.players) -> true
      # no changes
      true -> false
    end
  end

  defp sleep(last_sent) do
    dt = Time.diff(Time.utc_now, last_sent)
    if dt < @interval do
      # Logger.debug("sleeping for #{@interval - dt} seconds", Logger.metadata())

      Process.sleep((@interval - dt) * 1000)
    else
      Logger.debug("no rest for the wicked", Logger.metadata())
    end
  end

  defp via_registry(address), do: {:via, Registry, {:quester_registry, address}}

  defp address_to_string({{part_i, part_ii, part_iii, part_iv}, port}) do
    "#{part_i}.#{part_ii}.#{part_iii}.#{part_iv}:#{port}"
  end

  defp address_to_ip_string({{part_i, part_ii, part_iii, part_iv}, _port}) do
    "#{part_i}.#{part_ii}.#{part_iii}.#{part_iv}"
  end
end
