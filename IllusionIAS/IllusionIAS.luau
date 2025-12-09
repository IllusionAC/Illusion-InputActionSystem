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
local IASignal = require("@self/IllusionSignal")

local function getBindFolder()
	local existing = script:FindFirstChildOfClass("Folder")
	if existing then return existing end

	local folder = Instance.new("Folder")
	folder.Name = "BindFolder"
	folder.Parent = script
	return folder
end

local function modifiersEqualSet(a: {Enum.KeyCode?}, b: {Enum.KeyCode?}): boolean
	if #a ~= #b then return false end

	local counts: {[Enum.KeyCode]: number} = {}

	for _, key in a do
		if key then counts[key] = (counts[key] or 0) + 1 end
	end

	for _, key in b do
		if not key or not counts[key] or counts[key] == 0 then return false end
		counts[key] -= 1
	end

	return true
end

local function bindToString(bind: IAS.Bind): string
	local mods = table.clone(bind.Modifier)
	table.sort(mods, function(a: Enum.KeyCode?, b: Enum.KeyCode?): boolean
		return (a and a.Value or 0) < (b and b.Value or 0)
	end)

	local parts: {string} = {tostring(bind.KeyCode.Value)}

	for _, mod in mods do
		if mod then table.insert(parts, tostring(mod.Value)) end
	end

	return table.concat(parts, ":")
end

local function getBindsHash(binds: {IAS.Bind}): string
	local hashes: {string} = {}
	for _, bind in binds do table.insert(hashes, bindToString(bind)) end
	table.sort(hashes)
	return table.concat(hashes, "|")
end

local function deepCloneBinds(binds: {IAS.Bind}): {IAS.Bind}
	local cloned: {IAS.Bind} = {}

	for _, bind in binds do
		local clonedMods: {Enum.KeyCode?} = table.clone(bind.Modifier)
		table.insert(cloned, {KeyCode = bind.KeyCode, Modifier = clonedMods})
	end

	return cloned
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

		Binds = {},

		UIButton = nil,

		Active = false,
		
		Enabled = true,
		Priority = 1000,
		Sink = false,
		
		Cooldown = 0,

		TapRequired = 1,
		TapWindow = 0,

		Activated = IASignal.new(),
		
		SetHold = function() end,
		SetUIButton = function() end,
		SetBinds = function() end,
		SetCooldown = function() end,
		ResetCooldown = function() end,
		SetTapActivation = function() end,
		SetEnabled = function() end,
		IsEnabled = function() return true end,
		GetBinds = function(): {IAS.Bind} return {} end,
		SetPriority = function() end,
		GetPriority = function() return 1000 end,
		SetSink = function() end,
		GetSink = function() return false end,

		AddBind = function() end,
		SetBind = function() end,
		RemoveBind = function() end,
		EditBind = function() end,
		ClearBinds = function() end,
		
		Destroy = function() end,
	}

	local _PrevHold = true
	local _PrevBindsHash = ""
	local _PrevUIButton = nil
	local _PrevCooldown = 0
	local _PrevTapRequired = 1
	local _PrevTapWindow = 0
	local _ToggleState = false
	local _CooldownUntil = 0
	local _LastTapTime = 0
	local _TapCount = 0

	local modifiersState = {}
	local stateConnections: { RBXScriptConnection } = {}
	local rebuildScheduled = false
	
	local modifierToBindsMap: { [Enum.KeyCode]: {IAS.Bind} } = {}
	
	local function fire(active: boolean, pressed: boolean)
		if not self.Enabled then return end
		self.Active = active
		self.Activated:Fire(active, pressed)
	end

	local function rebuild()
		if rebuildScheduled then return end
		rebuildScheduled = true
		task.defer(function()
			local currentHash = getBindsHash(self.Binds)

			if not (currentHash == _PrevBindsHash
				and self.UIButton == _PrevUIButton
				and self.Hold == _PrevHold
				and self.Cooldown == _PrevCooldown
				and self.TapRequired == _PrevTapRequired
				and self.TapWindow == _PrevTapWindow) then

				_PrevBindsHash = currentHash
				_PrevUIButton = self.UIButton
				_PrevHold = self.Hold
				_PrevCooldown = self.Cooldown
				_PrevTapRequired = self.TapRequired
				_PrevTapWindow = self.TapWindow

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

				local function setUIButton(givenTable: { [Enum.KeyCode]: boolean } | { [Enum.KeyCode]: {IAS.Bind} })
					for keyEnum, _ in givenTable do
						if not createdActions[keyEnum.Name] then
							createAction(keyEnum, InputContext, self.UIButton)
							createdActions[keyEnum.Name] = true
						end
					end
				end

				setUIButton(bindLookup)
				setUIButton(modifierKeysSet)

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

					local tapCompletedPending = false

					local rbxConnection = action.StateChanged:Connect(function(pressed: boolean)
						if not bindDataList then return end
						if not self.Enabled then return end

						local anyBindSatisfied = false
						for _, bindData in bindDataList do
							local allModsPresent = true
							for _, modKey in bindData.Modifier do
								if modKey and not modifiersState[modKey] then
									allModsPresent = false
									break
								end
							end
							if allModsPresent then
								anyBindSatisfied = true
								break
							end
						end

						if pressed then
							local now = time()

							if self.TapRequired > 1 then
								if now - _LastTapTime > self.TapWindow then
									_TapCount = 0
								end

								_TapCount += 1
								_LastTapTime = now

								if _TapCount < self.TapRequired then
									tapCompletedPending = false
									return
								end

								_TapCount = 0
								tapCompletedPending = true
							else
								tapCompletedPending = true
							end

							if not anyBindSatisfied then
								tapCompletedPending = false
								return
							end

							if self.Hold then
								if self.Cooldown > 0 and now < _CooldownUntil then
									fire(self.Active, true)
									return
								end

								if self.Cooldown > 0 then
									_CooldownUntil = now + self.Cooldown
								end

								fire(true, true)
								return
							end

							if not _ToggleState then
								if self.Cooldown > 0 and now < _CooldownUntil then
									fire(false, true)
									return
								end

								_ToggleState = true
								self.Active = true

								if self.Cooldown > 0 then
									_CooldownUntil = now + self.Cooldown
								end

								fire(true, true)
								return
							end

							_ToggleState = false
							self.Active = false
							fire(false, true)
							return
						end

						if not tapCompletedPending then return end
						tapCompletedPending = false

						if self.Hold then
							if self.Active then
								fire(false, false)
							else
								fire(self.Active, false)
							end
						else
							fire(_ToggleState, false)
						end
					end)

					table.insert(stateConnections, rbxConnection)
				end
			end

			rebuildScheduled = false
		end)
	end

	function self:SetHold(hold: boolean)
		self.Hold = hold
		rebuild()
	end

	function self:SetUIButton(button: GuiButton?)
		self.UIButton = button
		rebuild()
	end
	
	function self:SetCooldown(cooldown: number)
		self.Cooldown = math.max(0, cooldown)
		rebuild()
	end
	
	function self:ResetCooldown()
		_CooldownUntil = 0
	end

	function self:SetTapActivation(requiredTaps: number, tapWindow: number)
		requiredTaps = math.max(1, requiredTaps)
		tapWindow = math.max(0, tapWindow)

		self.TapRequired = requiredTaps
		self.TapWindow = tapWindow

		_TapCount = 0
		_LastTapTime = 0
		rebuild()
	end
	
	function self:SetEnabled(enabled: boolean)
		self.Enabled = enabled
		
		if not enabled and self.Active and self.Hold then
			self.Active = false
			self.Activated:Fire(false, false)
		end
		
		InputContext.Enabled = self.Enabled
	end
	
	function self:IsEnabled(): boolean
		return self.Enabled
	end
	
	function self:SetPriority(number)
		self.Priority = number
		InputContext.Priority = self.Priority
	end

	function self:GetPriority()
		return self.Priority
	end

	function self:SetSink(boolean)
		self.Sink = boolean
		InputContext.Sink = self.Sink
	end

	function self:GetSink()
		return self.Sink
	end
	
	function self:GetBinds(): {IAS.Bind}
		return deepCloneBinds(self.Binds)
	end
	
	function self:AddBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		if not isValidKeyCode(mainKey) then return end
		
		local modifiers = {}
		
		for i = 1, select("#", ...) do
			local mod = select(i, ...)
			if mod and isValidKeyCode(mod) then
				table.insert(modifiers, mod)
			end
		end
		
		for _, m in modifiers do if m == mainKey then return end end

		for _, existing in self.Binds do
			if existing.KeyCode == mainKey and modifiersEqualSet(existing.Modifier, modifiers) then 
				return 
			end
		end
		
		table.insert(self.Binds, { KeyCode = mainKey, Modifier = modifiers })
		rebuild()
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
		rebuild()
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
				rebuild()
				return
			end
		end
	end

	function self:ClearBinds()
		table.clear(self.Binds)
		rebuild()
	end

	function self:Destroy()
		clearConnections(stateConnections)
		table.clear(modifiersState)
		table.clear(modifierToBindsMap)
		
		self.Activated:DisconnectAll()
		
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
