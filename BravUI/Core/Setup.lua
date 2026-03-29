-- BravUI/Core/Setup.lua
-- First-install wizard bootstrap
-- Full wizard UI lives in BravUI_Menu/Core/Wizard.lua (LoD)

local function LoadMenu()
  if C_AddOns and C_AddOns.LoadAddOn then
    return C_AddOns.LoadAddOn("BravUI_Menu")
  elseif LoadAddOn then
    return LoadAddOn("BravUI_Menu")
  end
end

local function LaunchWizard()
  local M = BravUI.Menu
  if not (M and M.ShowWizard) then
    local loaded, reason = LoadMenu()
    if not loaded then
      BravLib.Warn("BravUI_Menu non charge: " .. tostring(reason))
      return
    end
    M = BravUI.Menu
  end
  if M and M.ShowWizard then
    local ok, err = pcall(M.ShowWizard, M)
    if not ok then
      BravLib.Warn("Wizard: " .. tostring(err))
    end
  else
    -- Wizard pas encore implémenté — skip silencieusement
    BravUI_DB.global._welcomeSeen = true
  end
end

SLASH_BRAVWELCOME1 = "/bravwelcome"
SlashCmdList.BRAVWELCOME = LaunchWizard

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  C_Timer.After(1.5, function()
    BravUI_DB = BravUI_DB or {}
    BravUI_DB.global = BravUI_DB.global or {}

    -- Premiere installation : wizard obligatoire
    if not BravUI_DB.global._welcomeSeen then
      LaunchWizard()
      return
    end

    -- Si le mode est deja choisi (global ou perChar), les nouveaux chars
    -- sont auto-assignes dans Storage.AutoAssignNewChar() au PLAYER_LOGIN.
    -- Pas besoin de relancer le wizard.
  end)
end)
