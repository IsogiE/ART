local GlobalAddonName, EART = ...

BINDING_HEADER_EART = "Demo Raid Tools"
BINDING_NAME_EART_FIGHTLOG_OPEN = EART.L.BossWatcher
BINDING_NAME_EART_OPEN = EART.L.minimapmenu

local function make(name, command, description)
	_G["BINDING_NAME_CLICK "..name..":LeftButton"] = description
	local btn = CreateFrame("Button", name, nil, "SecureActionButtonTemplate")
	btn:SetAttribute("type", "macro")
	btn:SetAttribute("macrotext", command)
	btn:RegisterForClicks("AnyUp", "AnyDown")
end

for i=1,8 do
	make("EARTWM"..i, _G["SLASH_CLEAR_WORLD_MARKER1"].." "..i.."\n".._G["SLASH_WORLD_MARKER1"].." "..i, _G["WORLD_MARKER"..i])
end
make("EARTCWM", _G["SLASH_CLEAR_WORLD_MARKER1"].." 0", REMOVE_WORLD_MARKERS)
make("EARTTOGGLENOTE", "/rt note", EART.L.message)
for i=1,8 do
	make("EARTWM"..i.."CURSOR", _G["SLASH_WORLD_MARKER1"].." [@cursor] "..i, _G["WORLD_MARKER"..i].." @ ".._G["MOUSE_LABEL"])
end