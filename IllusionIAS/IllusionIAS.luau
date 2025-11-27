--!strict
--IllusionIAS.luau
--[[
///////////////////////////////////////////////
\\      Illusion's InputActionSystem         \\
//  Custom-made Module using the new IAS     //
\\ Metatable-free | Closure based OOP Module \\
//  More informations on the DevForum post   //
\\              By Illusion                  \\
///////////////////////////////////////////////
]]

local IAS = require("@self/TypeDefinition")
local Signal = require("@self/ScriptSignal")

local function getBindFolder()
	local existing = script:FindFirstChildOfClass("Folder")
	if existing then return existing end

	local folder = Instance.new("Folder")
	folder.Name = "BindFolder"
	folder.Parent = script
	return folder
end

local function modifiersEqualSet(a: {Enum.KeyCode?}, b: {Enum.KeyCode?}): boolean
	if (#a == 0 and #b == 0) then return true end
	if #a ~= #b then return false end

	local seen = {}
	for i = 1, #a do seen[a[i]] = (seen[a[i]] or 0) + 1 end
	for i = 1, #b do
		if not seen[b[i]] or seen[b[i]] <= 0 then return false end
		seen[b[i]] = seen[b[i]] - 1
	end

	for _, v in seen do if v ~= 0 then return false end end

	return true
end

local function bindsEqual(a: {IAS.Bind}, b: {IAS.Bind}): boolean
	if #a ~= #b then return false end

	local matched = {}
	for i = 1, #a do
		local A = a[i]
		local found = false
		for j = 1, #b do
			if not matched[j] then
				local B = b[j]
				if A.KeyCode == B.KeyCode and modifiersEqualSet(A.Modifier, B.Modifier) then
					matched[j] = true
					found = true
					break
				end
			end
		end
		if not found then return false end
	end
	return true
end

local function deepCloneBinds(binds: {IAS.Bind})
	local out = {}
	for i = 1, #binds do
		local b = binds[i]
		local mods = {}
		for j = 1, #b.Modifier do mods[j] = b.Modifier[j] end
		out[i] = { KeyCode = b.KeyCode, Modifier = mods }
	end
	return out
end

local function isValidKeyCode(key: any): boolean
	return typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode
end

local function createAction(key: Enum.KeyCode, InputContext: Instance, UIButton: GuiButton?)
	local action = Instance.new("InputAction")
	action.Name = key.Name

	local binding = Instance.new("InputBinding")
	binding.KeyCode = key

	if UIButton then binding.UIButton = UIButton end

	binding.Parent = action
	action.Parent = InputContext
end

local function clearConnections(stateConnections: {RBXScriptConnection}?)
	if not stateConnections then return end
	
	for i = #stateConnections, 1, -1 do
		local c = stateConnections[i]
		if c and c.Connected then c:Disconnect() end
		stateConnections[i] = nil
	end
end

local I2AS = {}
local activeBinds: { [string]: IAS.Object } = {}

function I2AS.new(name: string): IAS.Object
	if activeBinds[name] then error(("IAS with %q already exists"):format(name)) end

	local bindFolder = getBindFolder()

	local InputContext = Instance.new("InputContext")
	InputContext.Name = name
	InputContext.Parent = bindFolder

	local self: IAS.Object = {
		Name = name,
		
		Hold = true,
		_PrevHold = true,

		Binds = {},
		_PrevBinds = {},

		UIButton = nil,
		_PrevUIButton = nil,
		
		Active = false,
		_ToggleState = false,
		
		Enabled = true,
		
		Cooldown = 0,
		_PrevCooldown = 0,
		_CooldownUntil = 0,

		TapRequired = 1,
		TapWindow = 0,
		_PrevTapRequired = 1,
		_PrevTapWindow = 0,
		
		_LastTapTime = 0,
		_TapCount = 0,
		
		Activated = Signal.new(),
		
		SetHold = function() end,
		SetUIButton = function() end,
		SetBinds = function() end,
		SetCooldown = function() end,
		SetTapActivation = function() end,
		SetEnabled = function() end,
		IsEnabled = function() return true end,
		GetBinds = function() return {} end,

		AddBind = function() end,
		SetBind = function() end,
		RemoveBind = function() end,
		EditBind = function() end,
		ClearBinds = function() end,
		
		Destroy = function() end,
	}

	local modifiersState: { [Enum.KeyCode]: boolean } = {}
	local stateConnections: { RBXScriptConnection } = {}
	local rebuildScheduled = false
	
	local modifierToBindsMap: { [Enum.KeyCode]: {IAS.Bind} } = {}
	
	local function fire(active, pressed)
		if not self.Enabled then return end
		
		if active then
			local now = time()
			if self.Cooldown > 0 and now < self._CooldownUntil then return end
			if self.Cooldown > 0 then self._CooldownUntil = now + self.Cooldown end
		end

		self.Active = active
		self.Activated:Fire(active, pressed)
	end

	local function rebuild()
		clearConnections(stateConnections)

		for _, child in InputContext:GetChildren() do child:Destroy() end

		modifiersState = {}
		modifierToBindsMap = {}

		local bindLookup: { [Enum.KeyCode]: {IAS.Bind} } = {}
		local modifierKeysSet: { [Enum.KeyCode]: boolean } = {}

		for _, b in self.Binds do
			bindLookup[b.KeyCode] = bindLookup[b.KeyCode] or {}
			table.insert(bindLookup[b.KeyCode], b)
			
			for _, m in b.Modifier do
				if m and isValidKeyCode(m) then
					modifierKeysSet[m] = true
					modifierToBindsMap[m] = modifierToBindsMap[m] or {}
					table.insert(modifierToBindsMap[m], b)
				end
			end
		end

		local createdActions: { [string]: boolean } = {}

		for keyEnum, _ in bindLookup do
			if not createdActions[keyEnum.Name] then
				createAction(keyEnum, InputContext, self.UIButton)
				createdActions[keyEnum.Name] = true
			end
		end

		for modEnum, _ in modifierKeysSet do
			if not createdActions[modEnum.Name] then
				createAction(modEnum, InputContext, self.UIButton)
				createdActions[modEnum.Name] = true
			end
		end

		for _, action in InputContext:GetChildren() do
			if not action:IsA("InputAction") then continue end

			local keyEnum = Enum.KeyCode:FromName(action.Name)
			if not keyEnum then continue end

			local bindDataList = bindLookup[keyEnum]
			local isModifier = (bindDataList == nil)

			if isModifier then
				local rbxConnection = action.StateChanged:Connect(function(pressed: boolean)
					modifiersState[keyEnum] = pressed

					if self.Hold and not pressed and self.Active then
						local affectedBinds = modifierToBindsMap[keyEnum]
						if affectedBinds then
							for _, bind in affectedBinds do
								local allModsStillPressed = true
								for _, modKey in bind.Modifier do
									if modKey and not modifiersState[modKey] then
										allModsStillPressed = false
										break
									end
								end
								
								if not allModsStillPressed then
									fire(false, false)
									break
								end
							end
						end
					end
				end)
				
				table.insert(stateConnections, rbxConnection)
				continue
			end

			local rbxConnection = action.StateChanged:Connect(function(pressed: boolean)
				if not bindDataList then return end
				
				if not self.Enabled then return end

				local _anyBindSatisfied = false

				for _, bindData in bindDataList do
					local allModsPresent = true
					for _, modKey in bindData.Modifier do
						if modKey then
							if not modifiersState[modKey] then
								allModsPresent = false
								break
							end
						end
					end

					if allModsPresent then _anyBindSatisfied = true end
				end

				if pressed then
					local now = time()

					if self.TapRequired > 1 then
						if now - self._LastTapTime > self.TapWindow then 
							self._TapCount = 0
						end

						self._TapCount += 1
						self._LastTapTime = now

						if self._TapCount < self.TapRequired then return end

						self._TapCount = 0
					end
				end

				if self.Hold then
					if not _anyBindSatisfied and self.Active then
						fire(false, false)
						return
					end

					if _anyBindSatisfied then
						fire(pressed, pressed)
					end

					return
				end

				if pressed and _anyBindSatisfied then
					self._ToggleState = not self._ToggleState
					fire(self._ToggleState, pressed)
				elseif pressed and not _anyBindSatisfied then 
					return
				else 
					fire(self._ToggleState, pressed) 
				end
			end)

			table.insert(stateConnections, rbxConnection)
		end
	end

	local function scheduleRebuild()
		if rebuildScheduled then return end
		rebuildScheduled = true
		task.defer(function()
			if not (bindsEqual(self.Binds, self._PrevBinds)
				and self.UIButton == self._PrevUIButton
				and self.Hold == self._PrevHold
				and self.Cooldown == self._PrevCooldown
				and self.TapRequired == self._PrevTapRequired
				and self.TapWindow == self._PrevTapWindow) then

				self._PrevBinds = deepCloneBinds(self.Binds)
				self._PrevUIButton = self.UIButton
				self._PrevHold = self.Hold
				self._PrevCooldown = self.Cooldown
				self._PrevTapRequired = self.TapRequired
				self._PrevTapWindow = self.TapWindow

				rebuild()
			end
			
			rebuildScheduled = false
		end)
	end

	function self:SetHold(hold: boolean)
		self.Hold = hold
		scheduleRebuild()
	end

	function self:SetUIButton(button: GuiButton?)
		self.UIButton = button
		scheduleRebuild()
	end
	
	function self:SetCooldown(cooldown: number)
		self.Cooldown = math.max(0, cooldown)
		scheduleRebuild()
	end

	function self:SetTapActivation(requiredTaps: number, tapWindow: number)
		requiredTaps = math.max(1, requiredTaps)
		tapWindow = math.max(0, tapWindow)

		self.TapRequired = requiredTaps
		self.TapWindow = tapWindow

		self._TapCount = 0
		self._LastTapTime = 0
		scheduleRebuild()
	end
	
	function self:SetEnabled(enabled: boolean)
		self.Enabled = enabled
		
		if not enabled and self.Active and self.Hold then
			self.Active = false
			self.Activated:Fire(false, false)
		end
	end
	
	function self:IsEnabled(): boolean
		return self.Enabled
	end
	
	function self:GetBinds(): {IAS.Bind}
		return deepCloneBinds(self.Binds)
	end
	
	function self:AddBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		if not isValidKeyCode(mainKey) then
			warn(("Invalid KeyCode provided: %s"):format(tostring(mainKey)))
			return
		end
		
		local modifiers = {}
		local var = { ... }
		
		for i = 1, #var do 
			local mod = var[i]
			if mod and isValidKeyCode(mod) then
				table.insert(modifiers, mod)
			elseif mod then
				warn(("Invalid modifier KeyCode: %s"):format(tostring(mod)))
			end
		end
		
		for _, m in modifiers do if m == mainKey then return end end

		for _, existing in self.Binds do
			if existing.KeyCode == mainKey and modifiersEqualSet(existing.Modifier, modifiers) then 
				return 
			end
		end
		
		table.insert(self.Binds, { KeyCode = mainKey, Modifier = modifiers })
		scheduleRebuild()
	end
	
	function self:SetBinds(binds: {IAS.Bind})
		local validBinds = {}
		for _, bind in binds do
			if isValidKeyCode(bind.KeyCode) then
				local validMods = {}
				for _, mod in bind.Modifier do
					if not mod or isValidKeyCode(mod) then
						table.insert(validMods, mod)
					end
				end
				table.insert(validBinds, { KeyCode = bind.KeyCode, Modifier = validMods })
			end
		end
		
		self.Binds = deepCloneBinds(validBinds)
		scheduleRebuild()
	end
	
	function self:SetBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		table.clear(self.Binds)
		self:AddBind(mainKey, ...)
	end

	function self:EditBind(oldMain: Enum.KeyCode, oldMods: {Enum.KeyCode?}, newMain: Enum.KeyCode, newMods: {Enum.KeyCode?})
		for i = 1, #self.Binds do
			local bind = self.Binds[i]
			if bind.KeyCode == oldMain and modifiersEqualSet(bind.Modifier, oldMods) then
				table.remove(self.Binds, i)
				break
			end
		end

		self:AddBind(newMain, table.unpack(newMods or {}))
	end

	function self:RemoveBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		local modifiers = { ... }

		for i = 1, #self.Binds do
			local bind = self.Binds[i]
			if bind.KeyCode == mainKey and modifiersEqualSet(bind.Modifier, modifiers) then
				table.remove(self.Binds, i)
				scheduleRebuild()
				return
			end
		end
	end

	function self:ClearBinds()
		table.clear(self.Binds)
		scheduleRebuild()
	end

	function self:Destroy()
		clearConnections(stateConnections)
		table.clear(modifiersState)
		table.clear(modifierToBindsMap)

		if InputContext and InputContext.Parent then
			for _, child in InputContext:GetChildren() do child:Destroy() end
			InputContext:Destroy()
		end
		
		activeBinds[self.Name] = nil
	end

	activeBinds[name] = self
	return self
end

function I2AS.Get(name: string): IAS.Object?
	return activeBinds[name]
end

function I2AS.GetAll(): {[string]: IAS.Object}
	return activeBinds
end

return I2AS
