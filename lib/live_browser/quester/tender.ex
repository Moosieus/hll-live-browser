defmodule LiveBrowser.Quester.Tender do
  @moduledoc """
  Queries a server over A2S every N seconds. For the time being each tender will just store the latest reply and return it on call()
  """

  require Logger

  alias Phoenix.PubSub

  @type init_args() :: {:inet.ip_address(), :inet.port_number()}

  defmodule Data do
    defstruct [:address, :last_sent, :total_parts, :parts]
  end

  @behaviour :gen_statem

  @impl :gen_statem
  def callback_mode, do: :handle_event_function

  ## Initialization

  @spec child_spec(init_args) :: Supervisor.child_spec()
  def child_spec(address) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [address]},
      restart: :temporary
    }
  end

  @spec start_link(binary) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(address) do
    :gen_statem.start_link(via_registry(address), __MODULE__, address, timeout: 10 * 1000)
  end

  @impl :gen_statem
  def init(address) do
    Logger.metadata(address: address)

    # send self a message
    :ok = GenServer.call(LiveBrowser.Quester.UDP, {address, A2S.challenge_request(:info)})

    data = %Data{
      address: address,
      last_sent: Time.utc_now()
    }

    {:ok, :await_challenge, data, recv_timeout()}
  end

  @spec stop({:inet.ip_address(), :inet.port_number()}, any) :: :ok
  def stop(address, reason) do
    address |> via_registry |> GenServer.stop(reason)
  end

  ## Callbacks

  @impl :gen_statem
  def handle_event(:cast, packet, :await_challenge, data) do
    %Data{
      address: address
    } = data

    case A2S.parse_challenge(packet) do
      {:challenge, challenge} ->
        # Logger.debug("got challenge", Logger.metadata())
        :ok =
          GenServer.call(LiveBrowser.Quester.UDP, {address, A2S.sign_challenge(:info, challenge)})

        {:next_state, :await_response, data, recv_timeout()}

      {:immediate, msg} ->
        # Logger.debug("got immediate", Logger.metadata())
        report_and_next(msg, data)

      {:multipacket, part} ->
        # Logger.debug("got multipacket", Logger.metadata())
        {:next_state, :await_multipacket, %Data{data | parts: [part]}, recv_timeout()}
    end
  end

  @impl :gen_statem
  def handle_event(:cast, packet, :await_response, data) do
    %Data{
      address: address,
      last_sent: last_sent
    } = data

    case A2S.parse_response(packet) do
      {:info, _info} = msg ->
        report_and_next(msg, data)

      {:multipacket, {header, _body} = part} ->
        data = %Data{
          address: address,
          last_sent: last_sent,
          total_parts: header.total,
          parts: [part]
        }

        {:next_state, :await_multipacket, data, recv_timeout()}
    end
  end

  @impl :gen_statem
  def handle_event(:cast, packet, :await_multipacket, data) do
    %Data{
      total_parts: total_parts,
      parts: parts
    } = data

    {:multipacket, part} = A2S.parse_response(packet)
    parts = [part | parts]

    if Enum.count(parts) === total_parts do
      parts
      |> A2S.parse_multipacket_response()
      |> report_and_next(data)
    else
      {:next_state, :await_multipacket, %Data{data | parts: parts}, recv_timeout()}
    end
  end

  ## Timeouts

  def handle_event(:state_timeout, :await_timeout, state, %Data{} = data) do
    address = address_to_string(data.address)

    :ok = PubSub.broadcast(LiveBrowser.PubSub, "servers_info", {:info_timeout, address})

    Logger.info(tender_timeout: address, state: state, data: data)

    {:stop, :normal}
  end

  defp recv_timeout() do
    {:state_timeout, 3000, :await_timeout}
  end

  ## Functions

  defp report_and_next({:info, info}, data) do
    %Data{
      address: address,
      last_sent: last_sent
    } = data

    info = LiveBrowser.Quester.Enrichment.enrich(info, address)

    if changed?(info) do
      :ok = PubSub.broadcast(LiveBrowser.PubSub, "servers_info", {:update_info, info})
    end

    sleep(last_sent)
    :ok = GenServer.call(LiveBrowser.Quester.UDP, {address, A2S.challenge_request(:info)})

    data = %Data{
      address: address,
      last_sent: Time.utc_now()
    }

    {:next_state, :await_challenge, data, recv_timeout()}
  end

  defp changed?(info) do
    old = LiveBrowser.Quester.Cache.get_server(info.address)

    cond do
      # no previous entry
      old === nil -> true
      # significant field changed
      old.name !== info.name or old.map !== info.map or old.players !== info.players -> true
      # no changes
      true -> false
    end
  end

  defp sleep(last_sent) do
    dt = Time.diff(Time.utc_now(), last_sent)

    interval = interval()

    if dt < interval do
      Process.sleep((interval - dt) * 1000)
    end
  end

  defp via_registry(address), do: {:via, Registry, {:quester_registry, address}}

  defp interval() do
    Application.fetch_env!(:live_browser, :tender_interval)
  end

  ## Data formatting

  defp address_to_string({{part_i, part_ii, part_iii, part_iv}, port}) do
    "#{part_i}.#{part_ii}.#{part_iii}.#{part_iv}:#{port}"
  end
end
