-- BravUI/Modules/UnitFrames/Raid/Raid15.lua

BravUI.Frames = BravUI.Frames or {}

BravUI.RaidFactory.Create({
  dbKey          = "raid15",
  maxMembers     = 15,
  defaultColumns = 5,
  frameName      = "Raid15",
  globalPrefix   = "BravUI_Raid15Member",
  minRaidSize    = 1,
  maxRaidSize    = 15,
  defWidth       = 120,
  defHpH         = 20,
  defPwrH        = 6,
  defSpacing     = 4,
  defRowSpacing  = 4,
})
