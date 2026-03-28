-- BravUI/Modules/UnitFrames/Player/PlayerPet.lua
-- Pet UnitFrame — built via SimpleFrameFactory.

BravUI.Frames = BravUI.Frames or {}

local U = BravUI.Utils

BravUI.SimpleFrameFactory.Create({
  unit         = "pet",
  dbKey        = "pet",
  frameName    = "Pet",
  globalName   = "BravUI_PetClickOverlay",
  defaultPos   = { x = -200, y = -200 },
  defaultW     = 120,
  defaultHpH   = 18,
  defaultPwrH  = 6,
  textSizes    = { name = 9, hp = 9, pwr = 8 },
  throttleRate = 0.2,
  deadText     = "Mort",

  previewName    = "Familier",
  previewHp      = 72,
  previewHpText  = "72k",
  previewPwr     = 85,
  previewPwrText = "85k",
  previewHpColor = { 0.2, 0.8, 0.2 },

  extraEvents  = { "UNIT_PET" },
  onExtraEvent = function(event, unit, ctx)
    if event == "UNIT_PET" and U.SafeUnitIs(unit, "player") then
      ctx.Update()
      C_Timer.After(0.1, ctx.Update)
      C_Timer.After(0.3, ctx.Update)
      return true
    end
  end,

  publicFnName = "UpdatePetUF",
})
