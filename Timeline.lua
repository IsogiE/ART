local GlobalAddonName, ART = ...

-- Declare a global variable to hold the current popup
local currentPopup = nil

-- Ensure BossTimers is available
if not BossTimers then
    print("Error: BossTimers.lua was not loaded correctly.")
    return
end

-- Create a new module for Boss Timeline
local module = ART:New("BossTimeline", "Boss Timeline")
local ELib = ART.lib
local GetSpellInfo = ART.F.GetSpellInfo or GetSpellInfo

-- Initialize variables for storing custom timelines
local VART = nil
local selectedBoss = nil  -- Local variable to store the selected boss
local selectedOption = nil


function module.main:ADDON_LOADED()
    VART = _G.VART
    VART.BossTimeline = VART.BossTimeline or {}
end

-- Load and customize the UI when the options panel is loaded
function module.options:Load()
    self:CreateTilte("Boss Timeline")

    -- Use ELib:DropDown to create the dropdown for selecting bosses
    self.bossDropdown = ELib:DropDown(self, 200, 10):Point(10, -25):Size(216)
    self.bossDropdown:SetText("Select Boss")
    
    -- Add options to the dropdown dynamically from BossTimers
    if not BossTimers or next(BossTimers) == nil then
        print("Error: No boss data available in BossTimers.")
        return
    end

    self.bossDropdown.List = {}
    for bossName, _ in pairs(BossTimers) do
        table.insert(self.bossDropdown.List, {
            text = bossName, 
            func = function() 
                selectedBoss = bossName
                self.bossDropdown:SetText(bossName) 
					ELib:DropDownClose() 
            end
        })
    end
	
    -- Create a button to show the boss timeline in a new window
    local showTimelineButton = ELib:Button(self, "Show Timeline"):Size(100, 30):Point("TOPLEFT", 10, -60)
    showTimelineButton:SetScript("OnClick", function()
        if selectedBoss then  -- Ensure a boss is selected
            module:CreateBossTimelineWindow(selectedBoss)
        else
            print("Please select a boss from the dropdown.")
        end
    end)
end

-- Create a separate window for the timeline
function module:CreateBossTimelineWindow(boss)
    if not BossTimers[boss] then
        print("Error: No timeline data available for boss: " .. boss)
        return
    end

    local timeline = BossTimers[boss]
	
	local currentBossData = BossData[boss]

    -- Find the maximum time from all the events
    --local timeMax = 390
	
	-- Retrieve the enrage timer for Kyveza
	local timeMax = tonumber(BossData[boss][1].enrage[1])
	
	--timeMax = tonumber(currentBossData.enrage)

    -- Dynamically scale the window based on the maximum time
    local baseGraphWidth = 850  -- Base width for the graph (excluding buffer for ability names)
    local bufferWidth = 120  -- Space reserved for ability names
    local rowHeight = 40     -- Height for each ability row
    local windowWidth = baseGraphWidth + bufferWidth + 50  -- Add buffer and padding
    local windowHeight = (#timeline * rowHeight) + 100  -- Dynamically scale height based on number of rows

    -- Create a new frame for the pop-out window
	local window = ELib:Popup(""):Size(windowWidth, windowHeight):Point("CENTER", UIParent, "CENTER", 0, 0)
	
	window.title = window:CreateFontString(nil, "OVERLAY")
    window.title:SetFontObject("GameFontHighlight")
    window.title:SetPoint("TOP", window, "TOP", 0, -10)
    window.title:SetText(boss)

    window.message = window:CreateFontString(nil, "OVERLAY")	
    window.message:SetFontObject("GameFontNormal")
    window.message:SetPoint("TOP", window.title, "BOTTOM", 0, -10)
    window.message:SetWidth(windowWidth - 2)
    window.message:SetJustifyH("LEFT")
	
	window:Show()

    -- Calculate the dynamic content width based on the maximum time
    local graphWidth = max(baseGraphWidth, (timeMax * 10))  -- Scale graph width based on timeMax
    local contentWidth = graphWidth + bufferWidth  -- Total content width

    -- Create a scrollable content frame for long timelines (horizontal scrolling only)
    local scrollFrame = CreateFrame("ScrollFrame", nil, window)
    scrollFrame:SetPoint("TOPLEFT", 140, -40)
    scrollFrame:SetSize(baseGraphWidth, windowHeight - 100)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(contentWidth, (#timeline * rowHeight))  -- Adjust content width dynamically
    scrollFrame:SetScrollChild(content)

    -- Horizontal scrollbar setup
    horizontalScrollbar = CreateFrame("Slider", "CustomHorizontalScrollBar", window)
    horizontalScrollbar:SetOrientation('HORIZONTAL')  -- Make it horizontal
    horizontalScrollbar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 0, -30)
    horizontalScrollbar:SetSize(baseGraphWidth, 20)  -- Horizontal size

    -- Set range for horizontal scrolling and min/max values based on content width
    horizontalScrollbar:SetMinMaxValues(0, contentWidth - baseGraphWidth)
    horizontalScrollbar:SetValue(0)

    -- Manually create thumb (without vertical arrows)
    horizontalScrollbar.thumb = horizontalScrollbar:CreateTexture(nil, "BACKGROUND")
    horizontalScrollbar.thumb:SetColorTexture(1, 0.82, 0, 0.8)
    horizontalScrollbar:SetThumbTexture(horizontalScrollbar.thumb)
    local thumbSize = (baseGraphWidth / contentWidth) * baseGraphWidth  -- Calculate thumb size based on content
    horizontalScrollbar.thumb:SetSize(thumbSize, 20)  -- Dynamic thumb size

    horizontalScrollbar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetHorizontalScroll(value)
    end)

    -- Disable vertical scrolling completely
    scrollFrame:EnableMouseWheel(false)

    -- Limit horizontal scrolling to valid bounds
    scrollFrame:HookScript("OnMouseWheel", function(self, delta)
        local currentScroll = self:GetHorizontalScroll()
        local newScroll = currentScroll - delta * 30  -- Scroll amount
        newScroll = max(0, min(newScroll, contentWidth - baseGraphWidth))  -- Bound the scroll position
        scrollFrame:SetHorizontalScroll(newScroll)
        horizontalScrollbar:SetValue(newScroll)
    end)

    -- **Dynamic scaling factor for time markers** (this is where we fix the issue)
    local effectiveGraphWidth = graphWidth - bufferWidth -- Only the actual timeline area (excluding buffer)
    local scaleFactor = effectiveGraphWidth / timeMax  -- Scale based only on the graph area
	
	local tcount = 1
	
	--Create Export Button
	local showExportMRTButton = ELib:Button(scrollFrame, "Export"):Size(100, 20):Point("LEFT", horizontalScrollbar, "LEFT", -120, 0)
	
	
	--Start custom colors & time
	local count = 0
	local cR = 0
	local cG = 0
	local cB = 0
	local fightTime = 0
	local lineCount = 0
	
    for i, event in ipairs(timeline) do
	
		if count == 0 then
			cR = 0.8
			cG = 0.3
			cB = 0.3
		elseif count == 1 then
			cR = 0
			cG = 0.8
			cB = 1
		elseif count == 2 then
			cR = 0.2
			cG = 0.6
			cB = 0.4
		end
	
        -- Create a row label container (Frame) for each ability
		local rowLabelContainer = CreateFrame("Frame", nil, scrollFrame)
		rowLabelContainer:SetSize(bufferWidth, rowHeight)
		rowLabelContainer:SetPoint("TOPLEFT", -bufferWidth, -(i - 1) * rowHeight)  -- Ensure proper vertical alignment based on index
		
		 -- Create a row container (Frame) for each ability
        local rowContainer = CreateFrame("Frame", nil, content)
        rowContainer:SetSize(graphWidth, rowHeight)
        rowContainer:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)  -- Ensure proper vertical alignment based on index
		
        -- Add ability name label inside the row container
        local abilityText = rowLabelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        abilityText:SetPoint("LEFT", 10, 0)  -- Align ability name within the row
        abilityText:SetText(event.ability)
        abilityText:SetTextColor(1, 1, 0)  -- Yellow color for ability names

        -- Create a background for the ability row
        local abilityRowBackground = rowContainer:CreateTexture(nil, "BACKGROUND")
        abilityRowBackground:SetSize(graphWidth + bufferWidth, rowHeight)
        abilityRowBackground:SetPoint("LEFT", 0)
        abilityRowBackground:SetColorTexture(0.2, 0.2, 0.2, 0.8)

        -- Create a horizontal row divider inside the row container
        local rowDivider = rowContainer:CreateTexture(nil, "BACKGROUND")
        rowDivider:SetSize(graphWidth + bufferWidth, 2)
        rowDivider:SetPoint("BOTTOMLEFT", 0, 0)  -- Place divider at the bottom of the row
        rowDivider:SetColorTexture(0.5, 0.5, 0.5, 0.8)  -- Gray row divider
		
		
		local totalLines = floor(timeMax/60) + 1
		local runIndex = 0
			
		-- Add time interval lines at 60-second intervals
		while runIndex < totalLines do
			local intervalLine = content:CreateTexture(nil, "BACKGROUND")
			local intervalPosition = ((runIndex) * 600) -- Adjusted for buffer width
			intervalLine:SetSize(2, #timeline * rowHeight)
			intervalLine:SetPoint("TOPLEFT", intervalPosition, 0)
			intervalLine:SetColorTexture(0.6, 0.6, 0.6, 1)  -- Light gray for interval lines
			runIndex = runIndex + 1
		end
		
		local startPoint = 0

        -- Correctly position event markers in their respective rows (fix for markers falling out)
        for _, time in ipairs(event.time) do
			local duration = event.duration
			
			local sMinutes = floor(mod(time, 3600) / 60)
			local sSeconds = floor(mod(time, 60))
			
			if sSeconds < 10 then
			sSeconds = ("0" .. sSeconds)
			end
			
			local eMinutes = floor(mod(time + duration, 3600) / 60)
			local eSeconds = floor(mod(time + duration, 60))
			
			if eSeconds < 10 then
			eSeconds = ("0" .. eSeconds)
			end
			
function ShowPopupForTime(time)
    -- Check if there is already a popup open
    if currentPopup and currentPopup:IsShown() then
        currentPopup:Hide() -- Hide the existing popup
    end

    -- Create a simple popup window
    local popupWidth, popupHeight = 200, 400
    currentPopup = ELib:Popup(""):Size(popupWidth, popupHeight):Point("TOPLEFT", window, "TOPLEFT", -210, 0)

    -- Set the frame strata to HIGH to ensure it appears in front
    currentPopup:SetFrameStrata("HIGH")

    -- Set the frame level to a high number to ensure it's on top of other elements
    currentPopup:SetFrameLevel(100)
    
    -- Set the title of the popup window
    currentPopup.title = currentPopup:CreateFontString(nil, "OVERLAY")
    currentPopup.title:SetFontObject("GameFontHighlight")
    currentPopup.title:SetPoint("TOP", currentPopup, "TOP", 0, -10)
    currentPopup.title:SetText("Event at Time: " .. time)
    
    -- Get the player's class (localized name)
    local _, playerClass = UnitClass("player")

    -- Create an ELib EditBox to display the player's class
    local classBox = ELib:Edit(currentPopup):Size(100, 20):Point("TOPLEFT", currentPopup, "TOPLEFT", 20, -50)
    classBox:SetText(playerClass)

    -- Class label
    currentPopup.classLabel = currentPopup:CreateFontString(nil, "OVERLAY")
    currentPopup.classLabel:SetFontObject("GameFontNormal")
    currentPopup.classLabel:SetPoint("TOPLEFT", classBox, "TOPLEFT", 0, 15)
    currentPopup.classLabel:SetText("Class")
    
    -- Time label
    currentPopup.timeLabel = currentPopup:CreateFontString(nil, "OVERLAY")
    currentPopup.timeLabel:SetFontObject("GameFontNormal")
    currentPopup.timeLabel:SetPoint("BOTTOMLEFT", classBox, "BOTTOMLEFT", 0, -30)
    currentPopup.timeLabel:SetText("Time")
    
    -- Create an ELib EditBox to display the time selected
    local timeBox = ELib:Edit(currentPopup):Size(100, 20):Point("TOPLEFT", currentPopup.timeLabel, "TOPLEFT", 0, -15)
    timeBox:SetText(time)
    
    -- Type label
    currentPopup.typeLabel = currentPopup:CreateFontString(nil, "OVERLAY")
    currentPopup.typeLabel:SetFontObject("GameFontNormal")
    currentPopup.typeLabel:SetPoint("BOTTOMLEFT", timeBox, "BOTTOMLEFT", 0, -30)
    currentPopup.typeLabel:SetText("Type")

    -- Add a message or input inside the popup
    currentPopup.message = currentPopup:CreateFontString(nil, "OVERLAY")
    currentPopup.message:SetFontObject("GameFontNormal")
    currentPopup.message:SetPoint("CENTER", currentPopup, "CENTER", 0, 0)
    currentPopup.message:SetText("You clicked on time: " .. time .. "s")

    -- Optionally: Add a close button
    local closeButton = CreateFrame("Button", nil, currentPopup, "UIPanelButtonTemplate")
    closeButton:SetSize(80, 22)
    closeButton:SetPoint("BOTTOM", currentPopup, "BOTTOM", 0, 10)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function() 
        currentPopup:Hide() 
    end)

    -- Show the newly created popup
    currentPopup:Show()
end

			
			
			
		while(fightTime < time) do
		
			local emptyText = fightTime

			-- Create the texture for the emptyMarker inside the frame
			local emptyMarker = rowContainer:CreateTexture(nil, "OVERLAY")
			emptyMarker:SetPoint("LEFT", startPoint, 1, 0) -- Make the texture fill the frame
			emptyMarker:SetSize(10, rowHeight - 3)
			emptyMarker:SetColorTexture(0.2, 0.2, 0.2, 0)
			

			-- Optional: Add a tooltip to show exact time
					emptyMarker:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:SetText(emptyText)
						GameTooltip:Show()
					end)
					emptyMarker:SetScript("OnLeave", function()
						GameTooltip:Hide()
					end)
					
					-- **Add an OnClick event for the emptyMarker**
					emptyMarker:SetScript("OnMouseDown", function(self, button)
						if button == "LeftButton" then
							ShowPopupForTime(emptyText)  -- Call function to show popup window
						end
					end)
					

			fightTime = fightTime + 1
			startPoint = startPoint + 10
			
			
		end
		
		local dcount = 0
		local dur = tonumber(event.duration)
		local beenThere = 0
		
		for dcount = 1, duration do
			local eventMarker = rowContainer:CreateTexture(nil, "OVERLAY")
			
            eventMarker:SetSize(10, rowHeight - 3)
            eventMarker:SetPoint("LEFT", startPoint, 1, 0)  -- Now based on effectiveGraphWidth
            eventMarker:SetColorTexture(cR, cG, cB, 1)  -- Red color for event markers
			

            -- Optional: Add a tooltip to show exact time
            eventMarker:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(sMinutes .. ":" .. sSeconds .. "-" .. eMinutes .. ":" .. eSeconds, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            eventMarker:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
			
			fightTime = fightTime + 1
			startPoint = startPoint + 10
			
			dcount = dcount + 1
			
		end
		
			
        end
		
		while (fightTime < timeMax) do
		
		local emptyText = fightTime

			-- Create the texture for the emptyMarker inside the frame
			local emptyMarker = rowContainer:CreateTexture(nil, "OVERLAY")
			emptyMarker:SetPoint("LEFT", startPoint, 1, 0) -- Make the texture fill the frame
			emptyMarker:SetSize(10, rowHeight - 3)
			emptyMarker:SetColorTexture(0.2, 0.2, 0.2, 0)
			

			-- Optional: Add a tooltip to show exact time
					emptyMarker:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:SetText(emptyText)
						GameTooltip:Show()
					end)
					emptyMarker:SetScript("OnLeave", function()
						GameTooltip:Hide()
					end)
					

			fightTime = fightTime + 1
			startPoint = startPoint + 10
		
		end
		
		fightTime = 0
		startPoint = 0
		dcount = 0
		
		if count == 2 then
		count = 0 
		else 
			count = count + 1
		end
    end
	
end