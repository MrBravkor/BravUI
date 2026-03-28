-- BravUI/Modules/UnitFrames/Target/TargetCast.lua
-- Cast bar cible — construite via CastBarFactory.

BravUI.Frames.Target = BravUI.Frames.Target or {}

BravUI.CastBarFactory.Create({
  unit             = "target",
  dbKey            = "target",
  frameName        = "Target",
  globalPrefix     = "BravUI_Target",
  defaultW         = 220,
  defaultH         = 16,
  defaultSpellSize = 12,
  defaultTimeSize  = 12,
  refreshEvents    = { "PLAYER_TARGET_CHANGED" },
})
