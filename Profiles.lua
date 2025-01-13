local GlobalAddonName, EART = ...

local module = EART:New("Profiles",EART.L.Profiles)
local ELib,L = EART.lib,EART.L

local LibDeflate = LibStub:GetLibrary("LibDeflate")

local MAJOR_KEYS = {
	["Addon"]=true,
	["Profiles"]=true,
	["Profile"]=true,
	["ProfileKeys"]=true,
}

function module:ReselectProfileOnLoad()
	if VART.ProfileKeys and not VART.ProfileKeys[ EART.SDB.charKey ] then
		VART.ProfileKeys[ EART.SDB.charKey ] = "default"
	end
	if not VART.ProfileKeys or not VART.ProfileKeys[ EART.SDB.charKey ] or not VART.Profile or not VART.Profiles then
		return
	end
	local charProfile = VART.ProfileKeys[ EART.SDB.charKey ]
	if charProfile == VART.Profile then
		return
	end
	if not VART.Profiles[ charProfile ] then
		VART.ProfileKeys[ EART.SDB.charKey ] = VART.Profile
		return
	end
	local saveDB = {}
	VART.Profiles[ VART.Profile ] = saveDB
	
	for key,val in pairs(VART) do
		if not MAJOR_KEYS[key] then
			saveDB[key] = val
		end
	end
	
	for key,val in pairs(VART) do
		if not MAJOR_KEYS[key] then
			VART[key] = nil
		end
	end
	
	for key,val in pairs( VART.Profiles[ charProfile ] ) do
		if not MAJOR_KEYS[key] then
			VART[key] = val
		end
	end
	VART.Profiles[ charProfile ] = {}
	VART.Profile = charProfile
end

function module.options:Load()
	local function GetCurrentProfileName()
		return VART.Profile=="default" and L.ProfilesDefault or VART.Profile
	end
	local function GetCurrentProfilesList(func)
		local list = {
			{ text = L.ProfilesDefault, func = func, arg1 = "default", _sort = "0" },
		}
		for name,_ in pairs(VART.Profiles) do
			if name ~= "default" then
				list[#list + 1] = { text = name, func = func, arg1 = name, _sort = "1"..name }
			end
		end
		sort(list,function(a,b) return a._sort < b._sort end)
		return list
	end
	local function SaveCurrentProfiletoDB()
		local profileName = VART.Profile or "default"
		local saveDB = {}
		VART.Profiles[ profileName ] = saveDB
		
		for key,val in pairs(VART) do
			if not MAJOR_KEYS[key] then
				saveDB[key] = val
			end
		end
	end
	local function LoadProfileFromDB(profileName,isCopy)
		local loadDB = VART.Profiles[ profileName ]
		if not loadDB then
			print("Error")
			return
		end
		
		for key,val in pairs(VART) do
			if not MAJOR_KEYS[key] then
				VART[key] = nil
			end
		end
		for key,val in pairs(loadDB) do
			if not MAJOR_KEYS[key] then
				VART[key] = val
			end
		end
		
		if not isCopy then
			VART.Profiles[ profileName ] = {}
		end
		
		ReloadUI()
	end

	self:CreateTilte()

	self.introText = ELib:Text(self,L.ProfilesIntro,11):Size(650,200):Point(15,-45):Top():Color()
	
	self.currentText = ELib:Text(self,L.ProfilesCurrent,11):Size(650,200):Point(15,-90):Top():Color()
	self.currentName = ELib:Text(self,GetCurrentProfileName(),11):Size(650,200):Point(210,-90):Top()

	self.choseText = ELib:Text(self,L.ProfilesChooseDesc,11):Size(650,200):Point(15,-130):Top():Color()
	
	self.choseNewText = ELib:Text(self,L.ProfilesNew,11):Size(650,200):Point(15,-158):Top()
	self.choseNew = ELib:Edit(self):Size(170,20):Point(10,-170)
	
	self.choseNewButton = ELib:Button(self,L.ProfilesAdd):Size(70,20):Point("LEFT",self.choseNew,"RIGHT",0,0):OnClick(function (self)
		local text = module.options.choseNew:GetText()
		module.options.choseNew:SetText("")
		if text == "" or text == "default" or VART.Profiles[text] then
			return
		end
		VART.Profiles[text] = {}
		
		StaticPopupDialogs["EART_PROFILES_ACTIVATE"] = {
			text = L.ProfilesActivateAlert,
			button1 = L.YesText,
			button2 = L.NoText,
			OnAccept = function()
				SaveCurrentProfiletoDB()
				VART.Profile = text
				VART.ProfileKeys[ EART.SDB.charKey ] = text
				LoadProfileFromDB(text)
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show("EART_PROFILES_ACTIVATE")
	end)
	
	self.choseSelectText = ELib:Text(self,L.ProfilesSelect,11):Size(605,200):Point(335,-158):Top()
	self.choseSelectDropDown = ELib:DropDown(self,220,10):Point(330,-170):Size(235):SetText(GetCurrentProfileName())
	
	local function SelectProfile(_,name)
		ELib:DropDownClose()
		if name == VART.Profile then
			return
		end
		SaveCurrentProfiletoDB()
		VART.Profile = name
		VART.ProfileKeys[ EART.SDB.charKey ] = name
		LoadProfileFromDB(name)
	end
	function self.choseSelectDropDown:ToggleUpadte()
		self.List = GetCurrentProfilesList(SelectProfile)
	end
	
	local function CopyProfile(_,name)
		ELib:DropDownClose()
		LoadProfileFromDB(name,true)
	end
	self.copyText = ELib:Text(self,L.ProfilesCopy,11):Size(605,200):Point(15,-208):Top()
	self.copyDropDown = ELib:DropDown(self,220,10):Point(10,-220):Size(235)
	function self.copyDropDown:ToggleUpadte()
		self.List = GetCurrentProfilesList(CopyProfile)
		for i=1,#self.List do
			if self.List[i].arg1 == VART.Profile then
				for j=i,#self.List do
					self.List[j] = self.List[j+1]
				end
				break
			end
		end
	end
	
	local function DeleteProfile(_,name)
		ELib:DropDownClose()
		StaticPopupDialogs["EART_PROFILES_REMOVE"] = {
			text = L.ProfilesDeleteAlert,
			button1 = L.YesText,
			button2 = L.NoText,
			OnAccept = function()
				VART.Profiles[name] = nil
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show("EART_PROFILES_REMOVE")
	end
	self.deleteText = ELib:Text(self,L.ProfilesDelete,11):Size(605,200):Point(15,-258):Top()
	self.deleteDropDown = ELib:DropDown(self,220,10):Point(10,-270):Size(235)
	function self.deleteDropDown:ToggleUpadte()
		self.List = GetCurrentProfilesList(DeleteProfile)
		for i=1,#self.List do
			if self.List[i].arg1 == VART.Profile then
				for j=i,#self.List do
					self.List[j] = self.List[j+1]
				end
				break
			end
		end
		for i=1,#self.List do
			if self.List[i].arg1 == "default" then
				for j=i,#self.List do
					self.List[j] = self.List[j+1]
				end
				break
			end
		end
	end

	module.importWindow, module.exportWindow = EART.F.CreateImportExportWindows()

	function module.importWindow:ImportFunc(str)
		local headerLen = str:sub(1,4) == "EART" and 6 or (str:sub(1,4) == "EXRT" and 6 or 5)
	
		local header = str:sub(1,headerLen)
		-- Add MRTP and EXRTP to accepted prefixes
		if (header:sub(1,headerLen-1) ~= "EARTP" and 
			header:sub(1,headerLen-1) ~= "ARTP" and 
			header:sub(1,headerLen-1) ~= "MRTP" and 
			header:sub(1,headerLen-1) ~= "EXRTP") or 
			(header:sub(headerLen,headerLen) ~= "0" and header:sub(headerLen,headerLen) ~= "1") then
			
			StaticPopupDialogs["EART_PROFILES_IMPORT"] = {
				text = "|cffff0000"..ERROR_CAPS.."|r "..L.ProfilesFail3,
				button1 = OKAY,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
			StaticPopup_Show("EART_PROFILES_IMPORT")
			return
		end
	
		module:TextToProfile(str:sub(headerLen+1),header:sub(headerLen,headerLen)=="0")
	end

	self.exportButton = ELib:Button(self,L.ProfilesExport):Size(235,25):Point(10,-320):Tooltip(format(L.ProfilesExportTooltip,"|cffffff00"..L.sencounter..", "..L.LootHistory..", "..L.Attendance.."|r")):OnClick(function (self)
		module.exportWindow:NewPoint("CENTER",UIParent,0,0)
		module:ProfileToText(IsShiftKeyDown())
	end)

	self.importButton = ELib:Button(self,L.ProfilesImport):Size(235,25):Point("LEFT",self.exportButton,"RIGHT",85,0):OnClick(function (self)
		module.importWindow:NewPoint("CENTER",UIParent,0,0)
		module.importWindow:Show()
	end)

	self.selectReplaceWindow = ELib:Popup(L.ProfilesSelectModules):Size(300,350):Point("CENTER",UIParent,"CENTER",0,0)
	self.selectReplaceWindow.clist = ELib:ScrollCheckList(self.selectReplaceWindow):Point("TOP",0,-20):Size(290,302)
	function self.selectReplaceWindow.clist:UpdateAdditional()
		for i=1,#self.List do
			local line = self.List[i]
			if line.index then
				local key = self.L[line.index]
				line:SetText(type(module.db.EXPORT_KEYS[key]) == "string" and module.db.EXPORT_KEYS[key] or type(module.db.EXPORT_FULL_KEYS[key]) == "string" and module.db.EXPORT_FULL_KEYS[key] or key)
			end
		end
	end
	self.selectReplaceWindow.rewriteButton = ELib:Button(self.selectReplaceWindow,L.ProfilesRewrite):Point("BOTTOMLEFT",6,5):Size(140,20):OnClick(function(self)
		local keyToIndex = {}
		local clist = self:GetParent().clist
		for i=1,#clist.L do
			if clist.C[i] then
				keyToIndex[ clist.L[i] ] = true
			end
		end
		for k,v in pairs(self:GetParent().data) do
			if keyToIndex[k] then
				VART[k] = v
			end
		end
		ReloadUI()
	end)
	self.selectReplaceWindow.newButton = ELib:Button(self.selectReplaceWindow,L.ProfilesSaveAsNew):Point("BOTTOMRIGHT",-6,5):Size(140,20):OnClick(function(self)
		local keyToIndex = {}
		local clist = self:GetParent().clist
		for i=1,#clist.L do
			if clist.C[i] then
				keyToIndex[ clist.L[i] ] = true
			end
		end
		local new = {}
		for k,v in pairs(self:GetParent().data) do
			if keyToIndex[k] then
				new[k] = v
			end
		end
		local name = self:GetParent().name
		while VART.Profiles[name] do
			name = name .. "*"
		end
		print(L.ProfilesAddedText.." |cff00ff00"..name)
		VART.Profiles[name] = new
		self:GetParent():Hide()
	end)
	self.selectReplaceWindow:SetScript("OnHide",function(self)
		self.data = nil
		self.name = nil
	end)

	function module:SelectedReplace(dataTable,profileName)
		local l,c = {},{}
		for k,v in pairs(dataTable) do
			l[#l+1] = k
			c[#c+1] = true
		end
		sort(l,function(a,b) 
			local a1 = type(module.db.EXPORT_KEYS[a]) == "string" and module.db.EXPORT_KEYS[a] or type(module.db.EXPORT_FULL_KEYS[a]) == "string" and module.db.EXPORT_FULL_KEYS[a] or a
			local b1 = type(module.db.EXPORT_KEYS[b]) == "string" and module.db.EXPORT_KEYS[b] or type(module.db.EXPORT_FULL_KEYS[b]) == "string" and module.db.EXPORT_FULL_KEYS[b] or b
			return a1 < b1
		end)

		module.options.selectReplaceWindow.data = dataTable
		module.options.selectReplaceWindow.name = profileName
		module.options.selectReplaceWindow.clist.L = l
		module.options.selectReplaceWindow.clist.C = c
		module.options.selectReplaceWindow:Show()
	end
end

function module.main:ADDON_LOADED()
	if not VART then
		return
	end
	VART.ProfileKeys = VART.ProfileKeys or {}
	VART.Profiles = VART.Profiles or {}
	VART.Profile = VART.Profile or "default"
	
	VART.ProfileKeys[ EART.SDB.charKey ] = VART.Profile
end


module.db.EXPORT_KEYS = {
	["BattleRes"] = L.BattleRes,
	["BossWatcher"] = L.BossWatcher,
	["ExCD2"] = L.cd2,
	["InspectViewer"] = L.InspectViewer,
	["Interrupts"] = true,
	["InviteTool"] = L.invite,
	["Logging"] = L.Logging,
	["LootLink"] = L.LootLink,
	["Marks"] = L.marks,
	["MarksBar"] = L.marksbar,
	["MarksSimple"] = true,
	["Note"] = L.message,
	["RaidCheck"] = L.raidcheck,
	["RaidGroups"] = L.RaidGroups,
	["Timers"] = L.timers,
	["VisNote"] = L.VisualNote,
	["WhoPulled"] = L.WhoPulled,
}
module.db.EXPORT_FULL_KEYS = {
	["Encounter"] = L.sencounter,
	["Attendance"] = L.Attendance,
	["LootHistory"] = L.LootHistory,
	["Reminder"] = true,
	["Reminder2"] = true,
}

function module:ProfileToText(isFullExport)
	local new = {}
	for key,val in pairs(VART) do
		if module.db.EXPORT_KEYS[key] or (isFullExport and module.db.EXPORT_FULL_KEYS[key]) then
			new[key] = val
		end
	end
	local strlist = EART.F.TableToText(new)
	strlist[1] = (VART.Profile or "default"):sub(1,200):gsub(",","")..","..(EART.isClassic and "1" or "0")..","..strlist[1]
	local str = table.concat(strlist)

	local compressed
	if #str < 1000000 then
		compressed = LibDeflate:CompressDeflate(str,{level = 5})
	end
	local encoded
    if VART.EnableMRTCompatibility then
        encoded = "MRTP"..(compressed and "1" or "0")..LibDeflate:EncodeForPrint(compressed or str)
    else
        encoded = "ARTP"..(compressed and "1" or "0")..LibDeflate:EncodeForPrint(compressed or str)
    end

	EART.F.dprint("Str len:",#str,"Encoded len:",#encoded)

	if EART.isDev then
		module.db.exportTable = new
	end
	if not module.exportWindow then
		module.options:Load()
	end
	module.exportWindow.Edit:SetText(encoded)
	module.exportWindow:Show()
end

function module:TextToProfile(str,uncompressed)
	local decoded = LibDeflate:DecodeForPrint(str)
	local decompressed
	if uncompressed then
		decompressed = decoded
	else
		decompressed = LibDeflate:DecompressDeflate(decoded)
	end
	decoded = nil

	if not decompressed then
		print('error: import string is broken')
		return
	end

	local profileName,clientVersion,tableData = strsplit(",",decompressed,3)
	decompressed = nil

	if ((clientVersion == "0" and not EART.isClassic) or (clientVersion == "1" and EART.isClassic)) then
		local successful, res = pcall(EART.F.TextToTable,tableData)
		if EART.isDev then
			module.db.lastImportDB = res
			if module.db.exportTable and type(res)=="table" then
				module.db.diffTable = {}
				print("Compare table",EART.F.table_compare(res,module.db.exportTable,module.db.diffTable))
			end
		end
		if successful and res then
			StaticPopupDialogs["EART_PROFILES_IMPORT"] = {
				text = L.ProfilesNewProfile.." \""..profileName.."\"",
				button1 = L.ProfilesRewrite,
				button2 = L.ProfilesSaveAsNew,
				button3 = L.ProfilesSelectModules,
				button4 = CANCEL,
				selectCallbackByIndex = true,
				OnButton1 = function()
					for k,v in pairs(res) do
						VART[k] = v
					end
					ReloadUI()
				end,
				OnShow = function(self)
					--self.button1:Disable()	--disable before some testing
				end,
				OnButton2 = function()
					local name = profileName
					while VART.Profiles[name] do
						name = name .. "*"
					end
					print(L.ProfilesAddedText.." |cff00ff00"..name)
					VART.Profiles[name] = res
				end,
				OnButton3 = function()
					if not module.SelectedReplace then
						module.options:Load()
					end
					module:SelectedReplace(res,profileName)
				end,
				OnButton4 = function()
					res = nil
				end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
		else
			StaticPopupDialogs["EART_PROFILES_IMPORT"] = {
				text = L.ProfilesFail1..(res and "\nError code: "..res or ""),
				button1 = OKAY,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
		end
	else
		StaticPopupDialogs["EART_PROFILES_IMPORT"] = {
			text = L.ProfilesFail2,
			button1 = OKAY,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end

	StaticPopup_Show("EART_PROFILES_IMPORT")
end