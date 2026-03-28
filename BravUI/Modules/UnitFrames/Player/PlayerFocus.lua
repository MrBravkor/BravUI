-- BravUI/Modules/UnitFrames/Player/PlayerFocus.lua
-- Focus UnitFrame — built via SimpleFrameFactory.

BravUI.Frames = BravUI.Frames or {}

BravUI.SimpleFrameFactory.Create({
  unit         = "focus",
  dbKey        = "focus",
  frameName    = "Focus",
  globalName   = "BravUI_FocusClickOverlay",
  defaultPos   = { x = 0, y = -320 },
  defaultW     = 180,
  defaultHpH   = 22,
  defaultPwrH  = 8,
  textSizes    = { name = 11, hp = 11, pwr = 9 },
  throttleRate = 0.2,
  deadText     = "Mort",

  previewName     = "Focus",
  previewHp       = 72,
  previewHpText   = "72k",
  previewPwr      = 85,
  previewPwrText  = "85k",
  previewUseClass = true,

  extraEvents  = { "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_ENABLED" },
  onExtraEvent = function(event, _, ctx)
    if event == "PLAYER_REGEN_ENABLED"  then ctx.SyncClickOverlay();            return true end
    if event == "PLAYER_FOCUS_CHANGED"  then ctx.ApplyFromDB(); ctx.MarkDirty(); return true end
  end,

  publicFnName = "UpdateFocusUF",
})
