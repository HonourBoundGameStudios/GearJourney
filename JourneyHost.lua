-- JourneyHost -- the display-host seam (EPIC-K / IND-1).
-- Everything that needs the bar button repainted calls TitanJourney_RefreshButton();
-- only this file (and the host shim) knows WHICH display is hosting us. Today that
-- is Titan Panel; the LDB data object takes over at IND-3.

function TitanJourney_RefreshButton()
  if TitanPanelButton_UpdateButton then TitanPanelButton_UpdateButton("Journey") end
end
