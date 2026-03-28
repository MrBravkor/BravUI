-- BravUI/Modules/UnitFrames/Player/PlayerCast.lua
-- Cast bar joueur — construite via CastBarFactory.

BravUI.Frames.Player = BravUI.Frames.Player or {}

BravUI.CastBarFactory.Create({
  unit             = "player",
  dbKey            = "player",
  frameName        = "Player",
  globalPrefix     = "BravUI_Player",
  defaultW         = 220,
  defaultH         = 16,
  defaultSpellSize = 12,
  defaultTimeSize  = 12,
  refreshEvents    = { "PLAYER_SPECIALIZATION_CHANGED" },
})
