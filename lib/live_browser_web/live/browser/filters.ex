defmodule LiveBrowserWeb.Browser.Filters do
  @moduledoc """
  Manages all the filters for the live browser. Sends them as a keyword list of functions to be applied in order.
  This module is considered the "authoritative source" for filtering.
  """
  use Phoenix.LiveComponent

  import LiveBrowserWeb.CoreComponents

  alias LiveBrowser.Browser
  alias LiveBrowser.Browser.{FilterSet, Server}

  @impl true
  def update(%{filter_set: filter_set} = _assigns, socket) do
    form =
      filter_set
      |> Browser.change_filter_set()
      |> to_form()

    socket =
      socket
      |> assign(:filter_set, filter_set)
      |> assign(:form, form)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"filter_set" => params}, socket) do
    filter_set = socket.assigns.filter_set

    changeset = Browser.change_filter_set(filter_set, params)

    if changeset.valid? do
      filter_set = Ecto.Changeset.apply_changes(changeset)
      send(self(), {:filter_set, filter_set})

      {:noreply, socket}
    else
      form =
        filter_set
        |> Browser.change_filter_set(params)
        |> to_form(action: :validate)

      socket = assign(socket, :form, form)

      {:noreply, socket}
    end
  end
end
