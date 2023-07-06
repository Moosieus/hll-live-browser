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

    {:ok, socket}
  end

  # set min/max players (todo: add validation)
  def handle_event("set_range", %{"min" => min_str, "max" => max_str}, %{assigns: %{filters: filters}} = socket) do
    min = case Integer.parse(min_str) do
      {min, _} -> min
      :error -> {:noreply, socket}
    end

    max = case Integer.parse(max_str) do
      {max, _} -> max
      :error -> {:noreply, socket}
    end

    socket = socket
    |> assign(:min, min)
    |> assign(:max, max)

    filters = filters
    |> Keyword.put(:min, &(&1.players >= min))
    |> Keyword.put(:max, &(&1.players <= max))

    send(self(), {:update_filters, filters})

    {:noreply, socket}
  end

  def handle_event("set_continents", %{"continents" => continents}, %{assigns: %{filters: filters}} = socket) do
    filters = Keyword.put(filters, :continents, &(&1.location["continent"]["code"] in continents))

    send(self(), {:update_filters, filters})

    {:noreply, socket}
  end

  def handle_event("set_continents", _params, %{assigns: %{filters: filters}} = socket) do
    filters = Keyword.delete(filters, :continents)

    send(self(), {:update_filters, filters})

    {:noreply, socket}
  end

  def continent_codes() do
    %{
      "AF" => "Africa",
      # "AN" => "Antarctica", (lol)
      "AS" => "Asia",
      "EU" => "Europe",
      "NA" =>	"North america",
      "OC" =>	"Oceania",
      "SA" => "South America"
    }
  end
end
