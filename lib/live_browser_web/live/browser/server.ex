defmodule LiveBrowserWeb.Server do
  use Phoenix.LiveComponent

  defp map_full_name(name) do
    case name do
      "CAR_S_1944_P" -> "Carentan"
      "CT" -> "Carentan"
      "CT_N" -> "Carentan Night"
      "Driel_N" -> "Driel Night"
      "elalamein" -> "El Alamein"
      "elalamein_N" -> "El Alamein Night"
      "Foy_N" -> "Foy Night"
      "Hill400" -> "Hill 400"
      "Hurtgen_N" -> "Hürtgen Forest"
      "Hurtgen" -> "Hürtgen Forest"
      "Kharkov_N" -> "Kharkov Night"
      "Kursk_N" -> "Kursk Night"
      "Omaha" -> "Omaha Beach"
      "PHL" -> "Purple Heart Lane"
      "PHL_N" -> "Purple Heart Lane Night"
      "Remagen" -> "Remagen"
      "Remagen_N" -> "Remagen Night"
      "SME" -> "Sainte-Mère-Église"
      "SME_N" -> "Sainte-Mère-Église Night"
      "Stalin" -> "Stalingrad"
      "Stalin_N" -> "Stalingrad Night"
      "StMarie" -> "Sainte-Marie-du-Mont"
      "Utah" -> "Utah Beach"
      name -> name
    end
  end
end
