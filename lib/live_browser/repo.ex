defmodule LiveBrowser.Repo do
  use Ecto.Repo,
    otp_app: :live_browser,
    adapter: Ecto.Adapters.Postgres
end
