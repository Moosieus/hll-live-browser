import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :live_browser, LiveBrowser.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "live_browser_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :locus,
  load_from: "/Users/cameronduley/Library/Caches/locus_erlang/GeoLite2-City.mmdb.gz"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :live_browser, LiveBrowserWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+s4Ht0fuwqNJGSBjDjkdO/qq7l+/mql2+nzazYfxAsfsGMOeeiWns3WW9WG3GQ/u",
  server: false

# In test we don't send emails.
config :live_browser, LiveBrowser.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
