-- Started trying to hook into BetterCooldownManger, but not needed anyway so everything is related to BCM's NS and I'm too lazy to change it, mwwwaah love u 

local addonName, NS = ...

if not ACT then return end

local BCM = {}
ACT.BCM = BCM

local BCM_TARGET_VIEWER = "EssentialCooldownViewer"

local function GetCenteredXOffsets(count, itemWidth, padding)
    if count <= 0 then return {} end
    
    local totalWidth = (count * itemWidth) + ((count - 1) * padding)
    local startX = (-totalWidth / 2) + (itemWidth / 2)
    
    local offsets = {}
    for i = 1, count do
        offsets[i] = startX + (i - 1) * (itemWidth + padding)
    end
    return offsets
end

local function GetSortedIcons(viewer)
    local icons = {}
    for _, child in ipairs({viewer:GetChildren()}) do
        if child:IsShown() and (child.icon or child.Icon or child.cooldown or child.Cooldown) then
            table.insert(icons, child)
        end
    end

    table.sort(icons, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return icons
end

local function UpdateLayout(viewer)
    if not ACT.db or not ACT.db.profile.bcm_settings or not ACT.db.profile.bcm_settings.essential_centering then 
        return 
    end

    local icons = GetSortedIcons(viewer)
    if #icons == 0 then return end

    local iconWidth = icons[1]:GetWidth()
    local iconHeight = icons[1]:GetHeight()
    local padding = viewer.iconPadding
    
    local stride = viewer.stride or #icons 
    if stride < 1 then stride = #icons end

    local rows = {}
    for i, icon in ipairs(icons) do
        local rowIndex = math.floor((i - 1) / stride) + 1
        if not rows[rowIndex] then rows[rowIndex] = {} end
        table.insert(rows[rowIndex], icon)
    end

    for rowIndex, rowIcons in ipairs(rows) do
        local count = #rowIcons
        local xOffsets = GetCenteredXOffsets(count, iconWidth, padding)
        
        local yOffset = -(rowIndex - 1) * (iconHeight + padding)
        yOffset = yOffset - (iconHeight / 2)

        for i, icon in ipairs(rowIcons) do
            local x = xOffsets[i]
            
            local currentW, currentH = icon:GetSize()
            
            icon:ClearAllPoints()
            
            icon:SetSize(currentW, currentH)
            
            icon:SetPoint("CENTER", viewer, "TOP", x, yOffset)
        end
    end
end

function BCM:Initialize()
    local viewer = _G[BCM_TARGET_VIEWER]
    if not viewer then return end

    if viewer.RefreshLayout then
        hooksecurefunc(viewer, "RefreshLayout", function() UpdateLayout(viewer) end)
    end
    
    if viewer.Layout then
        hooksecurefunc(viewer, "Layout", function() UpdateLayout(viewer) end)
    end

    UpdateLayout(viewer)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    BCM:Initialize()
end)