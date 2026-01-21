local addonName, NS = ...

if not ACT then return end

local WhisperNotify = {}
ACT.WhisperNotify = WhisperNotify

local soundPath = "Interface\\AddOns\\" .. addonName .. "\\media\\sounds\\whisper.mp3"

local lastSoundTime = 0
local THROTTLE_SECONDS = 2

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    local currentTime = GetTime()
    
    if (currentTime - lastSoundTime) > THROTTLE_SECONDS then
        PlaySoundFile(soundPath, "Master")
        lastSoundTime = currentTime
    end
end)

function WhisperNotify:UpdateState()
    if ACT.db and ACT.db.profile and ACT.db.profile.whisper_settings and ACT.db.profile.whisper_settings.enabled then
        eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
        eventFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
    else
        eventFrame:UnregisterAllEvents()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    WhisperNotify:UpdateState()
end)