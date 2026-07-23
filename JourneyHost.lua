-- JourneyHost -- the display-host seam (EPIC-K / IND-1, IND-3).
-- Everything that needs the bar button repainted calls GearJourney_RefreshButton();
-- only this file (and the LDB shim in GearJourney.lua) knows HOW the button is
-- hosted. Since IND-3 that is a LibDataBroker data object -- updating it fires
-- the LDB callback and every hosting display (Titan's bridge included) repaints.

function GearJourney_RefreshButton()
  if GearJourney_HostRefresh then GearJourney_HostRefresh() end
end
