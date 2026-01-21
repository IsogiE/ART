-- Started trying to hook into BetterCooldownManger, but not needed anyway so everything is related to BCM's NS and I'm too lazy to change it, mwwwaah love u 

local addonName, NS = ...

if not ACT then return end

local BCM = {}
ACT.BCM = BCM

local BCM_TARGET_VIEWER = "EssentialCooldownViewer"
local BCM_UPDATE_THROTTLE = 0.5
local bcmTimer = 0

local bcmWorker = CreateFrame("Frame", "ACT_BCM_Worker", UIParent)
bcmWorker:Hide()

local function GetVisualSortedIcons(viewer)
    local icons = {}
    for _, child in ipairs({viewer:GetChildren()}) do
        if child:IsShown() and child.Icon then 
            table.insert(icons, child)
        end
    end

    table.sort(icons, function(a, b)
        local ay = a:GetTop() or 0
        local by = b:GetTop() or 0
        local ax = a:GetLeft() or 0
        local bx = b:GetLeft() or 0

        if math.abs(ay - by) > 5 then
            return ay > by 
        end
        return ax < bx
    end)
    return icons
end

local function UpdateLayout(viewer)
    local icons = GetVisualSortedIcons(viewer)
    if #icons == 0 then return end

    local iconSize = icons[1]:GetWidth()
    local padding = viewer.iconPadding 
    local maxColumns = viewer.stride
    
    local rows = {}
    local currentRow = {}
    
    for _, icon in ipairs(icons) do
        table.insert(currentRow, icon)
        if #currentRow >= maxColumns then
            table.insert(rows, currentRow)
            currentRow = {}
        end
    end
    if #currentRow > 0 then table.insert(rows, currentRow) end

    local startY = 0 
    for _, rowIcons in ipairs(rows) do
        local count = #rowIcons
        
        local rowWidth = (count * iconSize) + ((count - 1) * padding)
        local startX = -(rowWidth / 2) + (iconSize / 2)

        for _, icon in ipairs(rowIcons) do
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", viewer, "TOP", startX, startY - (iconSize / 2))
            
            startX = startX + iconSize + padding
        end
        
        startY = startY - (iconSize + padding)
    end
end

bcmWorker:SetScript("OnUpdate", function(self, elapsed)
    bcmTimer = bcmTimer + elapsed
    if bcmTimer < BCM_UPDATE_THROTTLE then return end
    bcmTimer = 0
    
    local viewer = _G[BCM_TARGET_VIEWER]
    if viewer and viewer:IsShown() then
        UpdateLayout(viewer)
    end
end)

function BCM:UpdateState()
    if not ACT.db or not ACT.db.profile or not ACT.db.profile.bcm_settings then return end
    
    local enabled = ACT.db.profile.bcm_settings.essential_centering
    if enabled then
        bcmWorker:Show()
    else
        bcmWorker:Hide()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    BCM:UpdateState()
end)