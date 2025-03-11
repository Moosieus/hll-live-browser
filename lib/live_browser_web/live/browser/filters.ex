defmodule LiveBrowserWeb.Browser.Filters do
  @moduledoc """
  Manages all the filters for the live browser. Sends them as a keyword list of functions to be applied in order.
  This module is considered the "authoritative source" for filtering.
  """
  use Phoenix.LiveComponent

  import LiveBrowserWeb.CoreComponents

  def mount(socket) do
    socket =
      socket
      |> assign(:continents, [])
      |> assign(:min, 30)
      |> assign(:max, 90)
      |> assign(:range_valid, true)
      # not assigned by default.
      |> assign(:exclude_night, false)

    {:ok, socket}
  end

  # set min/max players (todo: add validation)
  def handle_event("set_range", %{"min" => min_str, "max" => max_str}, socket) do
    %{assigns: %{filters: filters}} = socket

    case range_valid(min_str, max_str) do
      {min, max} ->
        socket =
          socket
          |> assign(:range_valid, true)
          |> assign(:min, min)
          |> assign(:max, max)

        filters =
          filters
          |> Keyword.put(:min, &(&1.a2s_players >= min))
          |> Keyword.put(:max, &(&1.a2s_players <= max))

        send(self(), {:update_filters, filters})

        {:noreply, socket}

      false ->
        {:noreply, assign(socket, :range_valid, false)}
    end
  end

  def handle_event("set_continents", %{"continents" => continents}, socket) do
    %{assigns: %{filters: filters}} = socket

    filter_fn = &(&1.country_code !== :unknown && &1.country_code in continents)

    filters = Keyword.put(filters, :continents, filter_fn)

    send(self(), {:update_filters, filters})

    {:noreply, assign(socket, :continents, continents)}
  end

  def handle_event("set_continents", _params, socket) do
    %{assigns: %{filters: filters}} = socket

    filters = Keyword.delete(filters, :continents)

    send(self(), {:update_filters, filters})

    {:noreply, assign(socket, :continents, [])}
  end

  def handle_event("set_night", %{"exclude_night" => "on"}, socket) do
    %{assigns: %{filters: filters}} = socket

    filters = Keyword.put(filters, :exclude_night, &(!String.ends_with?(&1.map, "_N")))

    send(self(), {:update_filters, filters})

    {:noreply, assign(socket, :exclude_night, true)}
  end

  def handle_event("set_night", _params, socket) do
    %{assigns: %{filters: filters}} = socket

    filters = Keyword.delete(filters, :exclude_night)

    send(self(), {:update_filters, filters})

    {:noreply, assign(socket, :exclude_night, false)}
  end

  def continent_codes() do
    %{
      # "AF" => "Africa", (There's no servers in Africa)
      # "AN" => "Antarctica", (lol)
      "AS" => "Asia",
      "EU" => "Europe",
      "NA" => "North America",
      "OC" => "Oceania",
      "SA" => "South America"
    }
  end

  def range_valid(min_str, max_str) do
    with {min, ""} <- Integer.parse(min_str),
         {max, ""} <- Integer.parse(max_str),
         true <- min >= 0 and max <= 100 and min <= max do
      {min, max}
    else
      _ ->
        false
    end
  end
end
