defmodule LiveBrowserWeb.Server do
  use Phoenix.LiveComponent

  defp map_full_name(name) do
    case name do
      "CAR_S_1944_P" -> "Carentan"
      "CT" -> "Carentan"
      "CT_N" -> "Carentan Night"
      "Driel_Day" -> "Driel"
      "Driel_N" -> "Driel Night"
      "elalamein" -> "El Alamein"
      "elalamein_N" -> "El Alamein Night"
      "Foy_N" -> "Foy Night"
      "Hill400" -> "Hill 400"
      "Hurtgen" -> "Hürtgen Forest"
      "Hurtgen_N" -> "Hürtgen Forest Night"
      "Kharkov_N" -> "Kharkov Night"
      "Kursk_N" -> "Kursk Night"
      "Mortain" <> _ -> "Mortain"
      "Mortain_N" <> _ -> "Mortain Night"
      "Mortain_SKM" <> _ -> "Mortain Skirmish"
      "Omaha" -> "Omaha Beach"
      "Omaha_N" -> "Omaha Beach Night"
      "PHL" -> "Purple Heart Lane"
      "PHL_N" -> "Purple Heart Lane Night"
      "Remagen_N" -> "Remagen Night"
      "SME" -> "Sainte-Mère-Église"
      "SME_N" -> "Sainte-Mère-Église Night"
      "Stalin" -> "Stalingrad"
      "Stalin_N" -> "Stalingrad Night"
      "StMarie" -> "Sainte-Marie-du-Mont"
      "StMarie_N" -> "Sainte-Marie-du-Mont Night"
      "Utah" -> "Utah Beach"
      "Utah_N" -> "Utah Beach Night"
      name -> name
    end
  end
end

[
  "DEV_N",
  "DEV_C_SKM",
  "DEV_N_Day_SKM",
  "DEV_K_Rain_SKM",
  "DEV_N_Morning",
  "DEV_M_Night_SKM",
  "DEV_F_RAIN_SKM",
  "DEV_M_SKM",
  "DEV_N_Night",
  "DEV_I_MORNING_SKM",
  "DEV_F_DUSK_SKM",
  "DEV_M_Rain_SKM",
  "DEV_I_SKM",
  "DEV_N_Night_SKM",
  "DEV_O_Morning",
  "DEV_H_Day_SKM",
  "DEV_K_Morning_SKM",
  "DEV_C_Night_SKM",
  "DEV_C_Day_SKM",
  "DEV_K_Night_SKM",
  "DEV_O_Dusk",
  "DEV_O_DUSK_SKM",
  "DEV_I_NIGHT_SKM",
  "DEV_H_Dusk_SKM",
  "DEV_F_DAY_SKM",
  "DEV_N_Morning_SKM"
]
