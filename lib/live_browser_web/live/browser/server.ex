defmodule LiveBrowserWeb.Server do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <tr class="divide-x divide-gray-200 dark:divide-gray-800">
      <td class="py-2">
        <div>
          <span class="text-xl dark:text-slate-100">{@server.name}</span>
        </div>
        <div class="text-gray-500 dark:text-zinc-400 dark:font-semibold px-1">
          {@server.gs_map} {@server.gamemode} {if(@server.gamemode == :Offensive,
            do: "(#{@server.offensive_attacker})"
          )} | {@server.time_of_day} | {@server.weather}
        </div>
      </td>
      <td class="py-2 text-center">
        {@server.country}
      </td>
      <td class="py-2 text-center">
        {@server.country_code}
      </td>
      <td class="py-2 text-right px-2">
        A2S: {@server.a2s_players} <br /> GS: {@server.gs_players} <br /> Qu:
        <span class="inline-block">{@server.join_queue}/{@server.max_queue}</span> <br /> VIP:
        <span class="inline-block">{@server.vip_queue}/{@server.max_vip}</span>
      </td>
      <td class="py-2 text-center">
        {if @server.new_match?, do: "Yes", else: "No"}
      </td>
      <td id={"#{@id}-last_changed"} class="py-2 text-center" phx-hook="locale_time">
        {DateTime.to_time(@server.last_changed)}
      </td>
    </tr>
    """
  end
end
