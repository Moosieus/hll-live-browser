defmodule LiveBrowserWeb.Filters do
  use Phoenix.LiveComponent

  @moduledoc """
  Manages all the filters for the live browser. Sends them as a keyword list of functions to be applied in order.
  This module is considered the "authoritative source" for filtering.
  """

  def mount(socket) do
    socket = socket
    |> assign(:continents, [])
    |> assign(:min, 30)
    |> assign(:max, 85)
    |> assign(:range_valid, true)

    {:ok, socket}
  end

  # set min/max players (todo: add validation)
  def handle_event("set_range", %{"min" => min_str, "max" => max_str}, %{assigns: %{filters: filters}} = socket) do

    case range_valid(min_str, max_str) do
      {min, max} ->
        socket = socket
        |> assign(:range_valid, true)
        |> assign(:min, min)
        |> assign(:max, max)

        filters = filters
        |> Keyword.put(:min, &(&1.players >= min))
        |> Keyword.put(:max, &(&1.players <= max))

        send(self(), {:update_filters, filters})

        {:noreply, socket}
      false ->
        socket = socket
        |> assign(:range_valid, false)

        {:noreply, socket}
    end
  end

  def handle_event("set_continents", %{"continents" => continents}, %{assigns: %{filters: filters}} = socket) do
    filters = Keyword.put(filters, :continents, &(&1.location !== :unknown && &1.location["continent"]["code"] in continents))

    send(self(), {:update_filters, filters})

    {:noreply, assign(socket, :continents, continents)}
  end

  def handle_event("set_continents", _params, %{assigns: %{filters: filters}} = socket) do
    filters = Keyword.delete(filters, :continents)

    send(self(), {:update_filters, filters})

    {:noreply, assign(socket, :continents, [])}
  end

  def continent_codes() do
    %{
      # "AF" => "Africa", (There's no servers in Africa)
      # "AN" => "Antarctica", (lol)
      "AS" => "Asia",
      "EU" => "Europe",
      "NA" =>	"North america",
      "OC" =>	"Oceania",
      "SA" => "South America"
    }
  end

  def range_valid(min_str, max_str) do
    with  {min, ""} <- Integer.parse(min_str),
          {max, ""} <- Integer.parse(max_str),
          true <- (min >= 0 and max <= 100 and min <= max) do
      {min, max}
    else _ ->
      false
    end
  end
end
