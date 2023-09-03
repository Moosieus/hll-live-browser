defmodule LiveBrowser.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do

    Logger.add_translator({Quester.GenStateMTranslator, :translate})

    children = [
      # Start the Telemetry supervisor
      LiveBrowserWeb.Telemetry,
      # Start the Ecto repository
      LiveBrowser.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: LiveBrowser.PubSub},
      # Start Finch
      {Finch, name: LiveBrowser.Finch},
      {Finch, name: Quester.Finch},
      # Start the Endpoint (http/https)
      LiveBrowserWeb.Endpoint,
      # Start a worker by calling: LiveBrowser.Worker.start_link(arg)
      # {LiveBrowser.Worker, arg}
      :locus.loader_child_spec(:city, ip_geo_database()),
      {Quester, [finch: Quester.Finch, udp_port: 20850]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveBrowser.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveBrowserWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp ip_geo_database() do
    Application.fetch_env!(:locus, :load_from)
  end
end
