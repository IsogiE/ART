local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local function GetSafeUnitName(unit)
    local name, realm = UnitNameUnmodified(unit)
    if not name then return "" end
    
    if issecretvalue(name) or (realm and issecretvalue(realm)) then
        return name
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function UpdateFrame(frame, force)
    if not force and
        (not ACT_AccountDB or not ACT_AccountDB.nickname_integrations or
            not ACT_AccountDB.nickname_integrations.Blizzard) then
        return
    end

    if not frame or frame:IsForbidden() or frame == PlayerFrame then
        return
    end

    local unit = frame.displayedUnit or frame.unit
    if unit and unit:match("nameplate") then
        return
    end

    local nameFrame = frame.name
    if not unit or not nameFrame or not UnitIsPlayer(unit) then
        return
    end

    local useNicknameFunction = ACT_AccountDB.nickname_integrations.Blizzard and ACT:HasNickname(unit)

    if useNicknameFunction then
        local nickname = ACT:GetNickname(unit)
        nameFrame:SetFormattedText(nickname)
    else
        local name = GetSafeUnitName(frame.unit)
        nameFrame:SetFormattedText(name)
    end
end

local function UpdatePartyFrames(force)
    if not PartyFrame then
        return
    end
    for i = 1, 4 do
        local frame = PartyFrame["MemberFrame" .. i]
        UpdateFrame(frame, force)
    end
end

local function UpdateRaidFrames(force)
    if not CompactRaidFrameContainer or not CompactRaidFrameContainer.frameUpdateList or
        not CompactRaidFrameContainer.frameUpdateList.normal then
        return
    end
    for _, frameGroup in pairs(CompactRaidFrameContainer.frameUpdateList.normal) do
        if frameGroup.memberUnitFrames then
            for _, frame in pairs(frameGroup.memberUnitFrames) do
                if frame.unitExists then
                    UpdateFrame(frame, force)
                end
            end
        end
    end
end

local function UpdateTargetFrame(force)
    UpdateFrame(TargetFrame, force)
end

-- Thx to Bart for figuring this out cause it caused issues with other addons
local function ForceUpdate()
    UpdatePartyFrames(true)
    UpdateRaidFrames(true)
    UpdateTargetFrame(true)
end

local function Update()
    if not ACT_AccountDB or not ACT_AccountDB.nickname_integrations or not ACT_AccountDB.nickname_integrations.Blizzard then
        return
    end
    UpdatePartyFrames()
    UpdateRaidFrames()
    UpdateTargetFrame()
end

local function Enable()
    if not ACT_AccountDB then
        ACT_AccountDB = {}
    end
    if not ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations = {}
    end
    ACT_AccountDB.nickname_integrations.Blizzard = true
    ForceUpdate()
end

local function Disable()
    if not ACT_AccountDB then
        ACT_AccountDB = {}
    end
    if not ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations = {}
    end
    ACT_AccountDB.nickname_integrations.Blizzard = false
    ForceUpdate()
end

local function Init()
    local hookedFrames = {}
    if PartyFrame then
        for i = 1, 4 do
            local memberFrame = PartyFrame["MemberFrame" .. i]
            if memberFrame and memberFrame.name then
                hooksecurefunc(memberFrame.name, "SetText", function()
                    UpdateFrame(memberFrame)
                end)
                hookedFrames[memberFrame.name] = true
            end
        end
    end

    if TargetFrame then
        hooksecurefunc(TargetFrame.name, "SetText", function()
            UpdateFrame(TargetFrame)
        end)
        hookedFrames[TargetFrame.name] = true
    end

    hooksecurefunc("DefaultCompactUnitFrameSetup", function(frame)
        if not hookedFrames[frame.name] then
            hooksecurefunc(frame.name, "SetText", function()
                UpdateFrame(frame)
            end)
            hookedFrames[frame.name] = true
        end
    end)
end

NicknameModule.nicknameFunctions["Blizzard"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}

Init()