-- JourneyHost -- the display-host seam (EPIC-K / IND-1, IND-3).
-- Everything that needs the bar button repainted calls TitanJourney_RefreshButton();
-- only this file (and the LDB shim in TitanJourney.lua) knows HOW the button is
-- hosted. Since IND-3 that is a LibDataBroker data object -- updating it fires
-- the LDB callback and every hosting display (Titan's bridge included) repaints.

function TitanJourney_RefreshButton()
  if TitanJourney_HostRefresh then TitanJourney_HostRefresh() end
end
