local GlobalAddonName, ART = ...

local module = ART:New("Nicknames", "Nicknames")
local ELib, L = ART.lib, ART.L

local VART = nil

local playerNicknames = {}

function module:PromptReload()
    if self.reloadPopup and self.reloadPopup:IsShown() then
        return
    end

    local popupFrame = ELib:Popup("Reload Required"):Size(450, 100)

    ELib:Text(popupFrame, "You have made changes that require a UI reload to apply the changes.\nWould you like to reload now?", 12)
        :Point("TOP", 0, -20)
        :Color(1, 1, 1)
        :Center() 

    ELib:Button(popupFrame, "Reload Now")
        :Size(100, 20)
        :Point("BOTTOM", -80, 15)
        :OnClick(function()
            popupFrame:Hide()
            ReloadUI()
        end)

    ELib:Button(popupFrame, "Later")
        :Size(100, 20)
        :Point("BOTTOM", 80, 15)
        :OnClick(function()
            popupFrame:Hide()
            print("|cFFFFFF00[ART Nicknames]|r Please reload your UI to apply the changes.")
        end)

    popupFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100) 

    popupFrame:SetFrameStrata("DIALOG")

    popupFrame:Show()

    self.reloadPopup = popupFrame
end

local function GetNicknamesMap()
    if type(VART.Nicknames) == "table" and #VART.Nicknames > 0 and type(VART.Nicknames[1]) == "table" then
        return VART.Nicknames[1]
    else
        return VART.Nicknames
    end
end

local function FindNicknameKey(nicknamesMap, nickname)
    nickname = nickname:lower()
    for key, _ in pairs(nicknamesMap) do
        if key:lower() == nickname then
            return key
        end
    end
    return nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == GlobalAddonName then
        module.main:ADDON_LOADED()
    end
end)

function module.main:ADDON_LOADED()
    VART = _G.VART
    VART.Nicknames = VART.Nicknames or {}
    
    if type(VART.Nicknames) == "table" and #VART.Nicknames > 0 and type(VART.Nicknames[1]) == "table" then
        playerNicknames = VART.Nicknames[1]
    else
        playerNicknames = VART.Nicknames
    end

    if not self.initialized then
        module.options:Load()
        self.initialized = true
    end
end

function module:ShowCharacterInputPopup(nickname, existingCharacter, callback)
    local popupFrame = ELib:Popup(existingCharacter and "Edit Character" or "Add New Character"):Size(300, 120)
    
    ELib:Text(popupFrame, "Please input character name", 12)
        :Point("TOP", 0, -20)
        :Color(1, 1, 1)
        :Center()

    local charInput = ELib:Edit(popupFrame, 50, false, "EARTInputBoxModernTemplate") 
        :Size(280, 20)
        :Point("TOP", 0, -40)
        :BackgroundText("")
    if existingCharacter then
        charInput:SetText(existingCharacter)
    end   

    ELib:Button(popupFrame, existingCharacter and "Save" or "Add")
        :Size(100, 20)
        :Point("BOTTOM", -60, 20)
        :OnClick(function()
            local characterName = charInput:GetText()
            if characterName ~= "" then
                if callback then
                    callback(characterName)
                end
                popupFrame:Hide()
            end
        end)

    ELib:Button(popupFrame, "Cancel")
        :Size(100, 20)
        :Point("BOTTOM", 60, 20)
        :OnClick(function()
            popupFrame:Hide()
        end)

    popupFrame:Show()
end

function module:UpdateDropdownList(dropdown, nickname)
    local list = {}
    local nicknamesMap = GetNicknamesMap()
    if nicknamesMap[nickname] and nicknamesMap[nickname].characters then
        for i, charData in ipairs(nicknamesMap[nickname].characters) do
            table.insert(list, {
                text = charData.character,
                func = function()
                    dropdown.selectedValue = charData.character
                    dropdown:SetText(charData.character)
                    ELib:DropDownClose()
                end
            })
        end
    end
    dropdown.List = list
end

function module.options:Load()
    if self.loaded then
        return
    end
    self.loaded = true

    self:CreateTilte()


    self.importBox = ELib:MultiEdit(self):Size(675, 60):Point("TOPLEFT", 10, -25)
    
    self.importButton = ELib:Button(self, "Import"):Size(100, 20):Point("TOPLEFT", 10, -90)
        :OnClick(function()
            local importString = self.importBox:GetText()
            if importString and importString ~= "" then
                self:ProcessImportString(importString)
                self.importBox:SetText("") 
            end
        end)

    self.nicknamesFrame = ELib:ScrollFrame(self):Size(675, 450):Point("TOPLEFT", 10, -120) 
    
    self.nicknamesFrame.content = CreateFrame("Frame", nil, self.nicknamesFrame)
    self.nicknamesFrame.content:SetSize(675, 450)
    self.nicknamesFrame:SetScrollChild(self.nicknamesFrame.content)

    self:CreateContent()

    self.wipeButton = ELib:Button(self, "Wipe All Data"):Size(120, 20):Point("BOTTOMLEFT", 10, 39)
    :OnClick(function()
        local popupFrame = ELib:Popup("Confirm Wipe"):Size(300, 120)
        
        ELib:Text(popupFrame, "Are you sure you want to delete all data?", 12)
            :Point("TOP", 0, -20)
            :Color(1, 0.1, 0.1) 
            :Center()
        
        ELib:Button(popupFrame, "Confirm"):Size(100, 20):Point("BOTTOM", -60, 20)
            :OnClick(function()
                wipe(GetNicknamesMap())  
                module:SaveNicknames() 
                self:CreateContent()
                popupFrame:Hide()
                module:PromptReload() 
            end)
        
        ELib:Button(popupFrame, "Cancel"):Size(100, 20):Point("BOTTOM", 60, 20)
            :OnClick(function()
                popupFrame:Hide()
            end)
        
        popupFrame:Show()
    end)
end

function module.options:ProcessImportString(importString)
    wipe(GetNicknamesMap())
    for _, playerData in ipairs({strsplit(";", importString)}) do
        playerData = strtrim(playerData)
        if playerData ~= "" then
            local nickname, characters = strsplit(":", playerData)
            nickname = strtrim(nickname)
            
            if nickname and characters then
                GetNicknamesMap()[nickname] = {
                    characters = {}
                }
                
                for _, charName in ipairs({strsplit(",", characters)}) do
                    charName = strtrim(charName)
                    if charName ~= "" then
                        table.insert(GetNicknamesMap()[nickname].characters, {
                            character = charName
                        })
                    end
                end
            end
        end
    end
    
    module:SaveNicknames()
    self:CreateContent()
    module:PromptReload() 
end

function module.options:CreateContent()
    local content = self.nicknamesFrame.content
    
    if content.elements then
        for _, element in pairs(content.elements) do
            element:Hide()
            element:SetParent(nil)
        end
    end
    content.elements = {}

    local title = ELib:Text(content, "Player Nicknames", 14):Point("TOPLEFT", 5, -5):Color(1, 1, 0)
    table.insert(content.elements, title)

    local charTitle = ELib:Text(content, "Player Characters", 14):Point("TOPLEFT", 190, -5):Color(1, 1, 0)
    table.insert(content.elements, charTitle)

    local offset = 30
    local sortedNicknames = {}
    local nicknamesMap = GetNicknamesMap()
    for nickname in pairs(nicknamesMap) do
        table.insert(sortedNicknames, nickname)
    end
    table.sort(sortedNicknames)

    for _, nickname in ipairs(sortedNicknames) do
        local nicknameText = ELib:Text(content, nickname, 12):Point("TOPLEFT", 10, -offset)
            :Center() 
        table.insert(content.elements, nicknameText)
        
        local dropdown = ELib:DropDown(content, 200, 10, "EARTDropDownMenuModernTemplate") 
            :Point("TOPLEFT", 195, -offset)
            :Size(200, 20)
        dropdown.selectedValue = nil
        module:UpdateDropdownList(dropdown, nickname)
        table.insert(content.elements, dropdown)

        local addBtn = ELib:Button(content, "Add")
            :Size(50, 20)
            :Point("TOPLEFT", 410, -offset)
            :OnClick(function()
                module:ShowCharacterInputPopup(nickname, nil, function(characterName)
                    nicknamesMap[nickname] = nicknamesMap[nickname] or {}
                    nicknamesMap[nickname].characters = nicknamesMap[nickname].characters or {}
                    
                    table.insert(nicknamesMap[nickname].characters, {
                        character = characterName
                    })
                    
                    module:UpdateDropdownList(dropdown, nickname)
                    module:SaveNicknames()
                    module:PromptReload() 
                end)
            end)
        table.insert(content.elements, addBtn)

        local editBtn = ELib:Button(content, "Edit")
            :Size(50, 20)
            :Point("TOPLEFT", 465, -offset)
            :OnClick(function()
                local selectedChar = dropdown.selectedValue
                if selectedChar then
                    module:ShowCharacterInputPopup(nickname, selectedChar, function(characterName)
                        if nicknamesMap[nickname] and nicknamesMap[nickname].characters then
                            for _, charData in ipairs(nicknamesMap[nickname].characters) do
                                if charData.character == selectedChar then
                                    charData.character = characterName
                                    break
                                end
                            end
                            module:UpdateDropdownList(dropdown, nickname)
                            dropdown.selectedValue = characterName
                            dropdown:SetText(characterName)
                            module:SaveNicknames()
                            module:PromptReload()  
                        end
                    end)
                end
            end)
        table.insert(content.elements, editBtn)

        local deleteBtn = ELib:Button(content, "Delete")
            :Size(60, 20)
            :Point("TOPLEFT", 520, -offset)
            :OnClick(function()
                local selectedChar = dropdown.selectedValue
                if selectedChar then
                    if nicknamesMap[nickname] and nicknamesMap[nickname].characters then
                        for i, charData in ipairs(nicknamesMap[nickname].characters) do
                            if charData.character == selectedChar then
                                table.remove(nicknamesMap[nickname].characters, i)
                                break
                            end
                        end
                        module:UpdateDropdownList(dropdown, nickname)
                        dropdown.selectedValue = nil
                        dropdown:SetText("Select Character")
                        module:SaveNicknames()
                        module:PromptReload()  
                    end
                end
            end)
        table.insert(content.elements, deleteBtn)

        offset = offset + 25
    end

    local totalContentHeight = offset + 25 
    
    content:SetHeight(math.max(totalContentHeight, self.nicknamesFrame:GetHeight()))
    
    self:UpdateScrollFrame()
end

function module.options:UpdateScrollFrame()
    local scrollFrame = self.nicknamesFrame
    local content = scrollFrame.content
    
    local height = content:GetHeight()
    local viewHeight = scrollFrame:GetHeight()
    
    content:SetHeight(math.max(height, viewHeight))
    scrollFrame:UpdateScrollChildRect()
    
    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:SetMinMaxValues(0, math.max(0, height - viewHeight))
        scrollFrame.ScrollBar:UpdateButtons()
    end
end

function module:LoadNicknames()
    playerNicknames = GetNicknamesMap() or {}
end

function module:SaveNicknames()
    if type(VART.Nicknames) == "table" and #VART.Nicknames > 0 and type(VART.Nicknames[1]) == "table" then
        VART.Nicknames[1] = playerNicknames
    else
        VART.Nicknames = playerNicknames
    end
end

ART.NicknameAPI = {
    GetNicknameByCharacter = function(self, characterName)
        if not characterName or type(characterName) ~= "string" then return nil end
        
        characterName = (strsplit("-", characterName:lower()) or characterName:lower())
        
        local nicknamesMap = GetNicknamesMap()
        
        if nicknamesMap then
            for nickname, data in pairs(nicknamesMap) do
                if data and data.characters then
                    for _, charData in ipairs(data.characters) do
                        if type(charData) == "table" and charData.character then
                            local storedChar = (strsplit("-", charData.character:lower()) or charData.character:lower())
                            if storedChar == characterName then
                                return nickname
                            end
                        end
                    end
                end
            end
        end
        return nil
    end,

    IsCharacterInNickname = function(self, characterName, nickname)
        if not characterName or not nickname or 
           type(characterName) ~= "string" or type(nickname) ~= "string" then 
            return false 
        end
        
        characterName = (strsplit("-", characterName:lower()) or characterName:lower())
        nickname = nickname:lower()
        
        local nicknamesMap = GetNicknamesMap()
        
        if nicknamesMap then
            local actualNicknameKey = FindNicknameKey(nicknamesMap, nickname)
            if actualNicknameKey and nicknamesMap[actualNicknameKey].characters then
                for _, charData in ipairs(nicknamesMap[actualNicknameKey].characters) do
                    if type(charData) == "table" and charData.character then
                        local storedChar = (strsplit("-", charData.character:lower()) or charData.character:lower())
                        if storedChar == characterName then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end,

    GetCharacterByNickname = function(self, nickname)
        if not nickname or type(nickname) ~= "string" then return nil end
        nickname = nickname:lower()
        
        local nicknamesMap = GetNicknamesMap()
        
        if nicknamesMap then
            local actualNicknameKey = FindNicknameKey(nicknamesMap, nickname)
            if actualNicknameKey and nicknamesMap[actualNicknameKey].characters and #nicknamesMap[actualNicknameKey].characters > 0 then
                return nicknamesMap[actualNicknameKey].characters[1].character
            end
        end
        return nil
    end,

    GetAllCharactersByNickname = function(self, nickname)
        if not nickname or type(nickname) ~= "string" then return {} end
        nickname = nickname:lower()
        
        local nicknamesMap = GetNicknamesMap()
        
        if nicknamesMap then
            local actualNicknameKey = FindNicknameKey(nicknamesMap, nickname)
            if actualNicknameKey and nicknamesMap[actualNicknameKey].characters then
                local characters = {}
                for _, charData in ipairs(nicknamesMap[actualNicknameKey].characters) do
                    if type(charData) == "table" and charData.character then
                        table.insert(characters, charData.character)
                    end
                end
                return characters
            end
        end
        return {}
    end,

    GetAllNicknames = function(self)
        if not VART or not VART.Nicknames then return {} end
        local nicknamesMap = GetNicknamesMap()
        return ART.F.table_copy2(nicknamesMap or {})
    end,
}

--- frames --- 

-- cell --

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, addonName)
    if addonName == "Cell" then
        UpdateCellNicknames()
    end
end)

function UpdateCellNicknames()
    if not C_AddOns.IsAddOnLoaded("Cell") then return end

    CellDB.nicknames.list = CellDB.nicknames.list or {}
    CellDB.nicknames.custom = true

    local existingNicknames = {}
    for _, entry in ipairs(CellDB.nicknames.list) do
        existingNicknames[entry] = true
    end

    local nicknameData = ART.NicknameAPI:GetAllNicknames()

    for nickname, data in pairs(nicknameData) do
        if data.characters then
            for _, charData in ipairs(data.characters) do
                if charData.character then
                    local entry = charData.character .. ":" .. nickname
                    if not existingNicknames[entry] then
                        table.insert(CellDB.nicknames.list, entry)
                        existingNicknames[entry] = true
                    end
                end
            end
        end
    end

    if Cell.funcs and Cell.funcs.UpdateNicknames then
        Cell.funcs.UpdateNicknames()
    end
end

if C_AddOns.IsAddOnLoaded("Cell") then
    UpdateCellNicknames()
end


-- elv -- 

local function UpdateElvUFTagsWithNicknames()
    if not (ElvUF and ElvUF.Tags) then return end

    if not ART or not ART.NicknameAPI then
        return
    end

    local function GetNickname(unit)
        local name = UnitName(unit)
        if name and ART.NicknameAPI then
            local nickname = ART.NicknameAPI:GetNicknameByCharacter(name)
            return nickname or name
        end
        return name
    end

    ElvUF.Tags.Events['nickname'] = 'UNIT_NAME_UPDATE'
    ElvUF.Tags.Methods['nickname'] = function(unit)
        return GetNickname(unit)
    end

    ElvUF.Tags.Events['nickname:veryshort'] = 'UNIT_NAME_UPDATE'
    ElvUF.Tags.Methods['nickname:veryshort'] = function(unit)
        return string.sub(GetNickname(unit), 1, 5)
    end

    ElvUF.Tags.Events['nickname:short'] = 'UNIT_NAME_UPDATE'
    ElvUF.Tags.Methods['nickname:short'] = function(unit)
        return string.sub(GetNickname(unit), 1, 8)
    end

    ElvUF.Tags.Events['nickname:medium'] = 'UNIT_NAME_UPDATE'
    ElvUF.Tags.Methods['nickname:medium'] = function(unit)
        return string.sub(GetNickname(unit), 1, 10)
    end

end

local elvFrame = CreateFrame("Frame")
elvFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
elvFrame:SetScript("OnEvent", function()
    UpdateElvUFTagsWithNicknames()
end)

if ElvUF and ElvUF.Tags then
    UpdateElvUFTagsWithNicknames()
end


-- grid2 --

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, event, addonName)
    if addonName == "Grid2" then
        OverrideGrid2NameStatusWithNicknames()
    end
end)

function OverrideGrid2NameStatusWithNicknames()
    if not Grid2 then return end
    if not (ART and ART.NicknameAPI) then return end

    local function GetNickname(unit)
        local name = UnitName(unit)
        if name then
            local nickname = ART.NicknameAPI:GetNicknameByCharacter(name)
            return nickname or name
        end
        return name
    end

    local NicknameStatus = Grid2.statusPrototype:new("name")

    NicknameStatus.IsActive = Grid2.statusLibrary.IsActive

    function NicknameStatus:UNIT_NAME_UPDATE(_, unit)
        self:UpdateIndicators(unit)
    end

    function NicknameStatus:OnEnable()
        self:RegisterEvent("UNIT_NAME_UPDATE")
    end

    function NicknameStatus:OnDisable()
        self:UnregisterEvent("UNIT_NAME_UPDATE")
    end

    function NicknameStatus:GetText(unit)
        return GetNickname(unit)
    end

    local function RegisterNicknameStatus(baseKey, dbx)
        Grid2:RegisterStatus(NicknameStatus, {"text"}, baseKey, dbx)
        return NicknameStatus
    end

    Grid2.setupFunc["name"] = RegisterNicknameStatus

    Grid2:DbSetStatusDefaultValue("name", {type = "name"})
end

if C_AddOns.IsAddOnLoaded("Grid2") then
    OverrideGrid2NameStatusWithNicknames()
end

-- default frames --

local f = CreateFrame("Frame")

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("UNIT_NAME_UPDATE")

local inCombat = false

local function GetNickname(unit)
    if not unit or not UnitExists(unit) then return nil end
    local name = UnitName(unit)
    if name and ART and ART.NicknameAPI then
        local nickname = ART.NicknameAPI:GetNicknameByCharacter(name)
        return nickname or name
    end
    return name
end

local function ApplyNicknameToFrame(frame)
    if not frame or not frame.unit or not UnitIsPlayer(frame.unit) then return end
    if frame.name then
        local nickname = GetNickname(frame.unit)
        if nickname then
            frame.name:SetText(nickname)
        end
    end
end

local function HookCompactFrames()
    for i = 1, 40 do
        local raidFrame = _G["CompactRaidFrame" .. i]
        if raidFrame then
            ApplyNicknameToFrame(raidFrame)
        end
    end

    for i = 1, 8 do
        local partyFrame = _G["CompactPartyFrameMember" .. i]
        if partyFrame then
            ApplyNicknameToFrame(partyFrame)
        end
    end
end

local function ForceNameUpdate()
    if CompactUnitFrame_UpdateName then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            ApplyNicknameToFrame(frame)
        end)
    end
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        HookCompactFrames()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_NAME_UPDATE" then
        if InCombatLockdown() then
            inCombat = true
        else
            HookCompactFrames()
        end
    end
end)

ForceNameUpdate()