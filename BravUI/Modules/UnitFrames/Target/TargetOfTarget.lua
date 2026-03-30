-- BravUI/Modules/UnitFrames/Target/TargetOfTarget.lua
-- Target-of-Target UnitFrame — built via SimpleFrameFactory.

BravUI.Frames = BravUI.Frames or {}

local U = BravUI.Utils

BravUI.SimpleFrameFactory.Create({
  unit         = "targettarget",
  dbKey        = "tot",
  frameName    = "ToT",
  globalName   = "BravUI_ToTClickOverlay",
  defaultPos   = { x = 0, y = -285 },
  defaultW     = 180,
  defaultHpH   = 22,
  defaultPwrH  = 8,
  textSizes    = { name = 11, hp = 11, pwr = 9 },
  throttleRate    = 0.05,
  deadText        = "Mort",
  allowReaction   = true,

  previewName     = "Mob",
  previewHp       = 45,
  previewHpText   = "45k",
  previewPwr      = 72,
  previewPwrText  = "72",
  previewUseClass = true,
  previewHpColor  = { 0.8, 0.2, 0.2 },

  extraHideCheck = function()
    return not U.SafeUnitExists("target")
  end,

  extraEvents  = { "PLAYER_TARGET_CHANGED", "UNIT_TARGET", "PLAYER_REGEN_ENABLED" },
  onExtraEvent = function(event, unit, ctx)
    if event == "PLAYER_REGEN_ENABLED" then ctx.SyncClickOverlay(); return true end
    if event == "PLAYER_TARGET_CHANGED" then
      ctx.MarkDirty()
      C_Timer.After(0.1, ctx.MarkDirty)
      C_Timer.After(0.3, ctx.MarkDirty)
      return true
    end
    if event == "UNIT_TARGET" and U.SafeUnitIs(unit, "target") then
      ctx.MarkDirty()
      C_Timer.After(0.1, ctx.MarkDirty)
      return true
    end
  end,

  publicFnName = "UpdateToTUF",
})
