local addonName, NS = ...

if not ACT then return end

local AuraOverride = {}
ACT.AuraOverride = AuraOverride

local CDM_VIEWERS = {"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer"}

local function IsCooldownFrame(frame)
    if not frame.cooldownInfo then return false end
    local cat = frame.cooldownInfo.category
    return cat == 0 or cat == 1
end

local function GetSmartDurationObject(spellID)
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    if chargeInfo then
        local success, chargeObj = pcall(C_Spell.GetSpellChargeDuration, spellID)
        if success and chargeObj then
            return chargeObj
        end
    end

    local success, durationObj = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    if success and durationObj then
        return durationObj
    end
    
    return nil
end

local function ApplyCDMOverride(frame)
    local cdm_db = ACT.db and ACT.db.profile and ACT.db.profile.cdm_settings
    if not cdm_db or not cdm_db.global_ignore_aura_override then return end
    
    if not IsCooldownFrame(frame) then return end

    local spellID = frame.cooldownInfo.overrideSpellID or frame.cooldownInfo.spellID
    if not spellID then return end

    if frame.Icon then
        local spellTexture = C_Spell.GetSpellTexture(spellID)
        if spellTexture then
            frame.Icon:SetTexture(spellTexture)
        end
    end

    if frame.Cooldown then
        frame.Cooldown.act_updating = true
        
        frame.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
        
        local durationObj = GetSmartDurationObject(spellID)
        
        if durationObj then
            frame.Cooldown:SetCooldownFromDurationObject(durationObj)
        else
            frame.Cooldown:Clear()
        end
        
        frame.Cooldown.act_updating = false
    end
end

local function HookCDMFrame(frame)
    if frame.act_cdm_hooked then return end
    frame.act_cdm_hooked = true

    if frame.Cooldown then
        hooksecurefunc(frame.Cooldown, "SetCooldown", function(self, start, duration)
            local cdm_db = ACT.db and ACT.db.profile and ACT.db.profile.cdm_settings
            if not cdm_db or not cdm_db.global_ignore_aura_override then return end
            if self.act_updating then return end

            local parent = self:GetParent()
            if not parent or not IsCooldownFrame(parent) then return end
            
            local spellID = parent.cooldownInfo.overrideSpellID or parent.cooldownInfo.spellID
            if not spellID then return end

            self.act_updating = true

            self:SetSwipeColor(0, 0, 0, 0.8)
            
            local durationObj = GetSmartDurationObject(spellID)
            
            if durationObj then
                self:SetCooldownFromDurationObject(durationObj)
            else
                self:Clear()
            end
            
            self.act_updating = false
        end)
    end

    if frame.Icon then
        hooksecurefunc(frame.Icon, "SetTexture", function(self, texture)
            local cdm_db = ACT.db and ACT.db.profile and ACT.db.profile.cdm_settings
            if not cdm_db or not cdm_db.global_ignore_aura_override then return end
            if self.act_updating then return end

            local parent = self:GetParent()
            if not parent or not IsCooldownFrame(parent) then return end

            local spellID = parent.cooldownInfo.overrideSpellID or parent.cooldownInfo.spellID
            if not spellID then return end

            local spellTexture = C_Spell.GetSpellTexture(spellID)
            
            if spellTexture then
                self.act_updating = true
                self:SetTexture(spellTexture)
                self.act_updating = false
            end
        end)
    end
end

local function ScanCDMViewers()
    for _, name in ipairs(CDM_VIEWERS) do
        local viewer = _G[name]
        if viewer and viewer.GetChildren then
            for _, child in ipairs({viewer:GetChildren()}) do
                if child.cooldownInfo then
                    HookCDMFrame(child)
                end
            end
        end
    end
end

function AuraOverride:UpdateState()
    ScanCDMViewers()
    
    local cdm_db = ACT.db and ACT.db.profile and ACT.db.profile.cdm_settings
    local isEnabled = cdm_db and cdm_db.global_ignore_aura_override

    for _, name in ipairs(CDM_VIEWERS) do
        local viewer = _G[name]
        if viewer and viewer.GetChildren then
            for _, child in ipairs({viewer:GetChildren()}) do
                if child:IsVisible() and child.cooldownInfo then
                    if isEnabled and IsCooldownFrame(child) then
                        ApplyCDMOverride(child)
                    else
                        if viewer.RefreshData then 
                            viewer:RefreshData() 
                        elseif child.Refresh then
                            child:Refresh()
                        end
                    end
                end
            end
        end
    end
end

function AuraOverride:Initialize()
    for _, name in ipairs(CDM_VIEWERS) do
        local viewer = _G[name]
        if viewer then
            if viewer.Layout then
                hooksecurefunc(viewer, "Layout", ScanCDMViewers)
            end
            if viewer.RefreshLayout then
                hooksecurefunc(viewer, "RefreshLayout", ScanCDMViewers)
            end
        end
    end
    ScanCDMViewers()
end