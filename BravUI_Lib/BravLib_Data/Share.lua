local BravLib = BravLib

BravLib.Share = {}

local Share = BravLib.Share

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PREFIX = "BravUI"
local MAX_CHUNK_SIZE = 240   -- 255 max par addon message, on garde de la marge pour le header
local TIMEOUT = 30           -- secondes avant timeout

-- Protocol messages:
-- OFFER:<profileName>:<totalChunks>
-- ACCEPT
-- DECLINE
-- CHUNK:<index>:<data>
-- DONE

-- ============================================================================
-- STATE
-- ============================================================================

local sending = nil   -- { target, channel, chunks, totalChunks, currentChunk, profileName, callback }
local receiving = nil -- { sender, profileName, totalChunks, chunks, receivedCount, timer }

-- ============================================================================
-- HELPERS
-- ============================================================================

local function SendAddonMessage(msg, channel, target)
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX, msg, channel, target)
    end
end

local function ChunkString(str, size)
    local chunks = {}
    for i = 1, #str, size do
        chunks[#chunks + 1] = str:sub(i, i + size - 1)
    end
    return chunks
end

local function CancelReceive()
    if receiving and receiving.timer then
        receiving.timer:Cancel()
    end
    receiving = nil
end

local function CancelSend()
    sending = nil
end

-- ============================================================================
-- SEND
-- ============================================================================

--- Share a profile via addon messages.
-- @param profileName string  Name of the profile to export and send
-- @param channel     string  "WHISPER", "PARTY", "RAID", or "GUILD"
-- @param target      string  Target player name (required for WHISPER, ignored otherwise)
-- @param callback    function(status, pct)  Optional progress callback
--   status: "accepted", "declined", "timeout", "progress", "ok"
function Share.Send(profileName, channel, target, callback)
    if not profileName then return false end
    channel = channel or "WHISPER"

    if channel == "WHISPER" and (not target or target == "") then
        BravLib.Warn("Share: target player required for WHISPER")
        return false
    end

    local encoded = BravLib.Storage.ExportProfile(profileName)
    if not encoded then
        BravLib.Warn("Share: failed to export profile '" .. tostring(profileName) .. "'")
        return false
    end

    local chunks = ChunkString(encoded, MAX_CHUNK_SIZE)

    sending = {
        target = target,
        channel = channel,
        profileName = profileName,
        chunks = chunks,
        totalChunks = #chunks,
        currentChunk = 0,
        callback = callback,
    }

    SendAddonMessage("OFFER:" .. profileName .. ":" .. #chunks, channel, target)
    BravLib.Debug("Share: sending offer for '" .. profileName .. "' via " .. channel)

    -- pour les channels non-WHISPER, on envoie directement sans attendre ACCEPT
    if channel ~= "WHISPER" then
        SendNextChunk()
    end

    return true
end

local function SendNextChunk()
    if not sending then return end

    sending.currentChunk = sending.currentChunk + 1
    local idx = sending.currentChunk

    if idx > sending.totalChunks then
        SendAddonMessage("DONE", sending.channel, sending.target)
        BravLib.Hooks.Fire("SHARE_SEND_COMPLETE", sending.profileName, sending.target)
        if sending.callback then sending.callback("ok", 100) end
        CancelSend()
        return
    end

    SendAddonMessage("CHUNK:" .. idx .. ":" .. sending.chunks[idx], sending.channel, sending.target)
    local pct = math.floor(idx / sending.totalChunks * 100)
    BravLib.Hooks.Fire("SHARE_SEND_PROGRESS", idx, sending.totalChunks)
    if sending.callback then sending.callback("progress", pct) end

    -- envoyer le chunk suivant au prochain frame pour ne pas flood
    C_Timer.After(0.05, SendNextChunk)
end

-- ============================================================================
-- RECEIVE
-- ============================================================================

local function OnOfferReceived(sender, profileName, totalChunks)
    if receiving then
        SendAddonMessage("DECLINE", "WHISPER", sender)
        return
    end

    -- popup de confirmation
    StaticPopupDialogs["BRAVUI_SHARE_ACCEPT"] = {
        text = sender .. " veut vous envoyer le profil BravUI: " .. profileName .. "\nAccepter?",
        button1 = ACCEPT or "Accepter",
        button2 = CANCEL or "Refuser",
        OnAccept = function()
            receiving = {
                sender = sender,
                profileName = profileName,
                totalChunks = totalChunks,
                chunks = {},
                receivedCount = 0,
            }
            -- timeout
            receiving.timer = C_Timer.NewTimer(TIMEOUT, function()
                BravLib.Warn("Share: reception timeout from " .. sender)
                CancelReceive()
            end)
            SendAddonMessage("ACCEPT", "WHISPER", sender)
            BravLib.Print("Reception du profil '" .. profileName .. "' de " .. sender .. "...")
        end,
        OnCancel = function()
            SendAddonMessage("DECLINE", "WHISPER", sender)
        end,
        timeout = TIMEOUT,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("BRAVUI_SHARE_ACCEPT")
end

local function OnChunkReceived(sender, index, data)
    if not receiving or receiving.sender ~= sender then return end

    receiving.chunks[index] = data
    receiving.receivedCount = receiving.receivedCount + 1
    BravLib.Hooks.Fire("SHARE_RECEIVE_PROGRESS", receiving.receivedCount, receiving.totalChunks)
end

local function OnDoneReceived(sender)
    if not receiving or receiving.sender ~= sender then return end

    -- annuler le timer
    if receiving.timer then receiving.timer:Cancel() end

    -- reconstituer la string
    local parts = {}
    for i = 1, receiving.totalChunks do
        if not receiving.chunks[i] then
            BravLib.Warn("Share: chunk manquant #" .. i)
            CancelReceive()
            return
        end
        parts[i] = receiving.chunks[i]
    end

    local encoded = table.concat(parts)
    local profileName = receiving.profileName

    -- importer le profil (auto-rename si existe deja)
    local targetName = profileName
    local suffix = 1
    while BravLib.Storage.GetRawDB().profiles[targetName] do
        suffix = suffix + 1
        targetName = profileName .. " (" .. suffix .. ")"
    end

    local ok = BravLib.Storage.ImportProfile(targetName, encoded)
    if ok then
        BravLib.Print("Profil '" .. targetName .. "' recu de " .. sender)
        BravLib.Hooks.Fire("SHARE_RECEIVE_COMPLETE", targetName, sender)
    else
        BravLib.Warn("Share: echec de l'import du profil de " .. sender)
    end

    CancelReceive()
end

-- ============================================================================
-- MESSAGE HANDLER
-- ============================================================================

local function OnAddonMessage(event, prefix, msg, channel, sender)
    if prefix ~= PREFIX then return end

    -- enlever le realm du sender si present (pour comparer)
    local senderName = sender:match("^([^%-]+)") or sender

    if msg:sub(1, 6) == "OFFER:" then
        local rest = msg:sub(7)
        local profName, totalStr = rest:match("^(.+):(%d+)$")
        if profName and totalStr then
            OnOfferReceived(senderName, profName, tonumber(totalStr))
        end

    elseif msg == "ACCEPT" then
        if sending and (senderName == sending.target or sender == sending.target) then
            if sending.callback then sending.callback("accepted") end
            SendNextChunk()
        end

    elseif msg == "DECLINE" then
        if sending and (senderName == sending.target or sender == sending.target) then
            if sending.callback then sending.callback("declined") end
            CancelSend()
        end

    elseif msg:sub(1, 6) == "CHUNK:" then
        local rest = msg:sub(7)
        local idxStr, data = rest:match("^(%d+):(.+)$")
        if idxStr and data then
            OnChunkReceived(senderName, tonumber(idxStr), data)
        end

    elseif msg == "DONE" then
        OnDoneReceived(senderName)
    end
end

-- ============================================================================
-- INIT
-- ============================================================================

local function Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    BravLib.Event.Register("CHAT_MSG_ADDON", OnAddonMessage)
    BravLib.Debug("Share module initialized")
end

-- on attend PLAYER_LOGIN pour etre sur que tout est charge
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    Init()
    self:UnregisterAllEvents()
end)
