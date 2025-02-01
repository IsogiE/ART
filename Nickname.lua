local GlobalAddonName, MRT = ...


importString = table.concat(DefaultNicknames)

local module = MRT:New("Nicknames", "Nicknames")
local ELib, L = MRT.lib, MRT.L

local VMRT = nil

local playerNicknames = {}

function module:PromptReload()
    if self.reloadPopup and self.reloadPopup:IsShown() then
        return
    end

    local popupFrame = ELib:Popup("Reload Required"):Size(400, 120)

    ELib:Text(popupFrame, "You have made changes that require a UI reload.\n\nWould you like to reload now?", 12)
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
            print("|cFFFFFF00[MRT Nicknames]|r Please reload your UI to apply the changes.")
        end)

    popupFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100) 

    popupFrame:SetFrameStrata("DIALOG")

    popupFrame:Show()

    self.reloadPopup = popupFrame
end

local function GetNicknamesMap()
    if type(VMRT.Nicknames) == "table" and #VMRT.Nicknames > 0 and type(VMRT.Nicknames[1]) == "table" then
        return VMRT.Nicknames[1]
    else
        return VMRT.Nicknames
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
    VMRT = _G.VMRT
    VMRT.Nicknames = VMRT.Nicknames or {}
    
    if type(VMRT.Nicknames) == "table" and #VMRT.Nicknames > 0 and type(VMRT.Nicknames[1]) == "table" then
        playerNicknames = VMRT.Nicknames[1]
    else
        playerNicknames = VMRT.Nicknames
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

    local charInput = ELib:Edit(popupFrame, 50, false, "ExRTInputBoxModernTemplate") 
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
	
	local title = ELib:Text(self, "Player Nicknames", 14):Point("TOPLEFT", 11, -101):Color(1, 1, 1)

    local chMRTitle = ELib:Text(self, "Player Characters", 14):Point("TOPLEFT", 201, -101):Color(1, 1, 1)


    self.importBox = ELib:MultiEdit(self):Size(675, 60):Point("TOPLEFT", 10, -25)
    
    self.importButton = ELib:Button(self, "Import"):Size(120, 20):Point("TOPRIGHT", -10, -92)
        :OnClick(function()
            local importString = self.importBox:GetText()
            if importString and importString ~= "" then
                self:ProcessImportString(importString)
                self.importBox:SetText("") 
            end
			module:PromptReload()
        end)

    self.nicknamesFrame = ELib:ScrollFrame(self):Size(675, 450):Point("TOPLEFT", 10, -120) 
    
    self.nicknamesFrame.content = CreateFrame("Frame", nil, self.nicknamesFrame)
    self.nicknamesFrame.content:SetSize(675, 450)
    self.nicknamesFrame:SetScrollChild(self.nicknamesFrame.content)

    self:CreateContent()

    self.wipeButton = ELib:Button(self, "Default Data"):Size(120, 20):Point("BOTTOMRIGHT", -10, 35)
    :OnClick(function()
        local popupFrame = ELib:Popup("Confirm Wipe"):Size(400, 120)
        
        ELib:Text(popupFrame, "\nAre you sure you want to return to default data?\nThis requires a reload.", 12)
            :Point("TOP", 0, -20)
			:Color(1, 1, 1)
			:Center() 
        
        ELib:Button(popupFrame, "Confirm"):Size(100, 20):Point("BOTTOM", -60, 20)
            :OnClick(function()
                wipe(GetNicknamesMap())  
                module:SaveNicknames() 
                self:CreateContent()
                popupFrame:Hide()
				ReloadUI()
                
            end)
        
        ELib:Button(popupFrame, "Cancel"):Size(100, 20):Point("BOTTOM", 60, 20)
            :OnClick(function()
                popupFrame:Hide()
            end)
        
        popupFrame:Show()
    end)
	
	if importString and importString ~= "" then
    self:ProcessImportString(importString)
	end
	
end

function module.options:ProcessImportString(importString)
    local nicknamesMap = GetNicknamesMap()
    local normalizedMap = {}
    
    for nickname, data in pairs(nicknamesMap) do
        local normalizedNick = nickname:lower()
        if not normalizedMap[normalizedNick] then
            normalizedMap[normalizedNick] = {
                originalCase = nickname,
                characters = data.characters or {}
            }
        else
            for _, char in ipairs(data.characters or {}) do
                local exists = false
                for _, existingChar in ipairs(normalizedMap[normalizedNick].characters) do
                    if existingChar.character:lower() == char.character:lower() then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(normalizedMap[normalizedNick].characters, char)
                end
            end
        end
    end
    
    for _, playerData in ipairs({strsplit(";", importString)}) do
        playerData = strtrim(playerData)
        if playerData ~= "" then
            local nickname, characters = strsplit(":", playerData)
            nickname = strtrim(nickname)
            
            if nickname and characters then
                local normalizedNick = nickname:lower()
                normalizedMap[normalizedNick] = normalizedMap[normalizedNick] or {
                    originalCase = nickname,
                    characters = {}
                }
                
                for _, charName in ipairs({strsplit(",", characters)}) do
                    charName = strtrim(charName)
                    if charName ~= "" then
                        local exists = false
                        for _, existingChar in ipairs(normalizedMap[normalizedNick].characters) do
                            if existingChar.character:lower() == charName:lower() then
                                exists = true
                                break
                            end
                        end
                        
                        if not exists then
                            table.insert(normalizedMap[normalizedNick].characters, {
                                character = charName
                            })
                        end
                    end
                end
            end
        end
    end
    
    wipe(nicknamesMap)
    for _, data in pairs(normalizedMap) do
        nicknamesMap[data.originalCase] = {
            characters = data.characters
        }
    end
    
    module:SaveNicknames()
    self:CreateContent()
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

    local offset = 30
    local sortedNicknames = {}
    local nicknamesMap = GetNicknamesMap()
    for nickname in pairs(nicknamesMap) do
        table.insert(sortedNicknames, nickname)
    end
    table.sort(sortedNicknames)
	
	local first = 0

    for _, nickname in ipairs(sortedNicknames) do
	
		if first == 0 then
			offset = 5
		end
	
        local nicknameText = ELib:Text(content, nickname, 12):Point("TOPLEFT", 10, -offset)
            :Center() 
        table.insert(content.elements, nicknameText)
		
        
        local dropdown = ELib:DropDown(content, 184, 10, "ExRTDropDownMenuModernTemplate") 
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

		first = 1
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
    if type(VMRT.Nicknames) == "table" and #VMRT.Nicknames > 0 and type(VMRT.Nicknames[1]) == "table" then
        VMRT.Nicknames[1] = playerNicknames
    else
        VMRT.Nicknames = playerNicknames
    end
end