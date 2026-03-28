-- BravUI/Modules/UnitFrames/Player/PlayerPetCast.lua
-- Cast bar familier — construite via CastBarFactory.

BravUI.Frames.Pet = BravUI.Frames.Pet or {}

BravUI.CastBarFactory.Create({
  unit                = "pet",
  dbKey               = "pet",
  frameName           = "Pet",
  globalPrefix        = "BravUI_Pet",
  defaultW            = 120,
  defaultH            = 14,
  defaultSpellSize    = 10,
  defaultTimeSize     = 10,
  preUnitRefreshEvent = "UNIT_PET",
})
