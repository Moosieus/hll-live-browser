# HLL LiveBrowser

An experimental live browser for Hell Let Loose.

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more
  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

## Todo
- Update `:last_changed` to be used as a `DateTime` instead of `Time`
- Add proper validation on min/max input
- Investigate rendering w/ assigns + LiveComponents
- Add "No results" message
- Add frontend theme w/ dark mode
- Format timestamps to local timezones
