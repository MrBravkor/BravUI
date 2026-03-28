-- BravUI/Modules/UnitFrames/Raid/Raid25.lua

BravUI.Frames = BravUI.Frames or {}

BravUI.RaidFactory.Create({
  dbKey          = "raid25",
  maxMembers     = 25,
  defaultColumns = 5,
  frameName      = "Raid25",
  globalPrefix   = "BravUI_Raid25Member",
  minRaidSize    = 16,
  maxRaidSize    = 25,
  defWidth       = 110,
  defHpH         = 20,
  defPwrH        = 6,
  defSpacing     = 4,
  defRowSpacing  = 4,
})
