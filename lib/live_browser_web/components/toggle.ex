defmodule LiveBrowserWeb.Toggle do
  use Phoenix.Component

  attr :toggled, :boolean, default: false
  attr :label, :string, default: ""

  attr :class, :string, default: nil
  attr :rest, :global

  def render(assigns) do
    ~H"""
      <div class={["flex text-center", @class]} @rest>
        <button
          type="button"
          class={"#{bg_color(@toggled)} relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-indigo-600 focus:ring-offset-2"}
          role="switch">
            <span aria-hidden="true" class={"#{translate_x(@toggled)} pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"}></span>
        </button>
        <span class="ml-3 text-sm">
          <span class="font-medium text-gray-900"><%= @label %></span>
        </span>
      </div>
    """
  end

  def bg_color(toggled) when is_boolean(toggled) do
    if toggled, do: "bg-indigo-600", else: "bg-gray-200"
  end

  def translate_x(toggled) when is_boolean(toggled) do
    if toggled, do: "translate-x-5", else: "translate-x-0"
  end
end
