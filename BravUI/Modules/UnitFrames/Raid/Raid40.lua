-- BravUI/Modules/UnitFrames/Raid/Raid40.lua

BravUI.Frames = BravUI.Frames or {}

BravUI.RaidFactory.Create({
  dbKey          = "raid40",
  maxMembers     = 40,
  defaultColumns = 8,
  frameName      = "Raid40",
  globalPrefix   = "BravUI_Raid40Member",
  minRaidSize    = 26,
  maxRaidSize    = 40,
  defWidth       = 90,
  defHpH         = 18,
  defPwrH        = 5,
  defSpacing     = 4,
  defRowSpacing  = 4,
})
