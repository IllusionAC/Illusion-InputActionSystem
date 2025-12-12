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
	local na: {[Enum.KeyCode]: number} = {}
	local nb: {[Enum.KeyCode]: number} = {}

	for _, v in a do
		if v then na[v] = (na[v] or 0) + 1 end
	end
	for _, v in b do
		if v then nb[v] = (nb[v] or 0) + 1 end
	end

	for k, va in na do
		if nb[k] ~= va then return false end
	end
	for k, vb in nb do
		if na[k] ~= vb then return false end
	end
	return true
end

local function bindToString(bind: IAS.Bind): string
	local mods = {}
	for _, m in bind.Modifier do if m then table.insert(mods, m.Value) end end
	table.sort(mods)
	local parts = { tostring(bind.KeyCode.Value) }
	for _, v in mods do table.insert(parts, tostring(v)) end
	return table.concat(parts, ":")
end

local function getBindsHash(binds: {IAS.Bind}): string
	local hashes = {}
	for _, bind in binds do table.insert(hashes, bindToString(bind)) end
	table.sort(hashes)
	return table.concat(hashes, "|")
end

local function deepCloneBinds(binds: {IAS.Bind}): {IAS.Bind}
	local cloned: {IAS.Bind} = {}
	for _, bind in binds do
		local clonedMods: {Enum.KeyCode?} = {}
		for _, m in bind.Modifier do
			if m then table.insert(clonedMods, m) end
		end
		table.insert(cloned, { KeyCode = bind.KeyCode, Modifier = clonedMods })
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

	if UIButton then 
		binding.UIButton = UIButton 
	end

	binding.Parent = action
	action.Parent = InputContext
end

local function clearConnections(stateConnections: {RBXScriptConnection}?)
	if not stateConnections then return end
	for i = #stateConnections, 1, -1 do
		local c = stateConnections[i]
		if c and c.Connected then
			c:Disconnect()
		end
		stateConnections[i] = nil
	end
end

local function pickBestSatisfiedBind(bindList: {IAS.Bind}, modifiersStateLocal: { [Enum.KeyCode]: boolean })
	local bestBind: IAS.Bind? = nil
	local bestCount = -1

	for _, bindData in bindList do
		local allModsPresent = true
		local modCount = 0
		for _, modKey in bindData.Modifier do
			if modKey then
				modCount += 1
				if not modifiersStateLocal[modKey] then
					allModsPresent = false
					break
				end
			end
		end

		if allModsPresent and modCount > bestCount then
			bestBind = bindData
			bestCount = modCount
		end
	end

	return bestBind, bestCount
end

local IIAS = {}
IIAS.contextedBinds = {} :: {[string]: {Enabled: boolean, Members: {[string]: boolean}}}

local activeBinds: { [string]: IAS.Object } = {}

function IIAS.new(name: string): IAS.Object
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

		InputBufferEnabled = false,
		InputBufferTime = 0.15,

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
		SetInputBufferEnabled = function() end,
		SetInputBufferTime = function() end,

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

	local _ToggleState = false
	local _CooldownUntil = 0
	local _LastTapTime = 0
	local _TapCount = 0
	local _ActiveBindCount = 0

	local _ActiveMainKey: Enum.KeyCode? = nil
	local _Buffered = false
	local _BufferedTime = 0
	local _BufferedKey: Enum.KeyCode? = nil

	local modifiersState: { [Enum.KeyCode]: boolean } = {}
	local stateConnections: { RBXScriptConnection } = {}
	local rebuildScheduled = false

	local modifierToBindsMap: { [Enum.KeyCode]: {IAS.Bind} } = {}

	local mainKeysDown: { [Enum.KeyCode]: boolean } = {}
	local activeKeysCounted: { [Enum.KeyCode]: boolean } = {}

	local blockedPresses: { [Enum.KeyCode]: boolean } = {}

	local function fire(active: boolean, pressed: boolean)
		if not self.Enabled then return end
		self.Active = active
		self.Activated:Fire(active, pressed)
	end

	local function tryConsumeBuffer()
		if not _Buffered then return false end

		if (time() - _BufferedTime) > self.InputBufferTime then
			_Buffered = false
			_BufferedKey = nil
			return false
		end

		if _ActiveMainKey and _ActiveMainKey ~= _BufferedKey then
			return false
		end

		local now = time()
		if self.Cooldown > 0 and now < _CooldownUntil then
			_Buffered = false
			_BufferedKey = nil
			return false
		end

		_Buffered = false
		if not _BufferedKey then return false end
		local keyEnum = _BufferedKey
		_BufferedKey = nil

		if self.Hold then
			_ActiveMainKey = keyEnum
			activeKeysCounted = { [keyEnum] = true }
			_ActiveBindCount = 1
			if self.Cooldown > 0 then _CooldownUntil = now + self.Cooldown end
			fire(true, true)
			return true
		else
			if self.Cooldown > 0 then _CooldownUntil = now + self.Cooldown end
			_ToggleState = not _ToggleState
			self.Active = _ToggleState
			_ActiveMainKey = keyEnum
			activeKeysCounted = { [keyEnum] = true }
			fire(_ToggleState, true)
			return true
		end
	end

	local function scheduleRebuild()
		if rebuildScheduled or not activeBinds[self.Name] then return end
		rebuildScheduled = true
		task.defer(function()
			local currentHash = getBindsHash(self.Binds)

			if not (currentHash == _PrevBindsHash
				and self.UIButton == _PrevUIButton
				and self.Hold == _PrevHold) then

				_PrevBindsHash = currentHash
				_PrevUIButton = self.UIButton
				_PrevHold = self.Hold

				_TapCount = 0
				_LastTapTime = 0

				clearConnections(stateConnections)

				for _, child in InputContext:GetChildren() do child:Destroy() end

				modifiersState = {}
				modifierToBindsMap = {}
				mainKeysDown = {}
				activeKeysCounted = {}
				blockedPresses = {}

				local bindLookup: { [Enum.KeyCode]: {IAS.Bind} } = {}
				local modifierKeysSet: { [Enum.KeyCode]: boolean } = {}

				for _, b in self.Binds do
					if not b or not isValidKeyCode(b.KeyCode) then continue end
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
						if self.UIButton and keyEnum == Enum.KeyCode.Unknown then
							createAction(keyEnum, InputContext, self.UIButton)
						else
							createAction(keyEnum, InputContext)
						end
						createdActions[keyEnum.Name] = true
					end
				end

				for keyEnum, _ in modifierKeysSet do
					if not createdActions[keyEnum.Name] then
						createAction(keyEnum, InputContext)
						createdActions[keyEnum.Name] = true
						modifiersState[keyEnum] = false
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
						end)

						table.insert(stateConnections, rbxConnection)
						continue
					end

					local rbxConnection = action.StateChanged:Connect(function(pressed: boolean)
						mainKeysDown[keyEnum] = pressed

						if not self.Enabled then return end

						local isUIButton = (keyEnum == Enum.KeyCode.Unknown)

						local bestBind, _ = pickBestSatisfiedBind(bindDataList, modifiersState)
						local bindSatisfied = (bestBind ~= nil)

						local now = time()

						if pressed then
							if _ActiveMainKey and _ActiveMainKey ~= keyEnum then
								if self.InputBufferEnabled then
									_Buffered = true
									_BufferedTime = now
									_BufferedKey = keyEnum
								end

								return
							end

							if self.TapRequired > 1 then
								if now - _LastTapTime > self.TapWindow then
									_TapCount = 1
								else
									_TapCount += 1
								end
								_LastTapTime = now

								if _TapCount < self.TapRequired then
									return
								end
							end

							if not bindSatisfied and not isUIButton then
								return
							end

							if self.Cooldown > 0 and now < _CooldownUntil then
								fire(false, true)
								blockedPresses[keyEnum] = true
								return
							end

							if self.Cooldown > 0 then
								_CooldownUntil = now + self.Cooldown
							end

							if self.Hold then
								_ActiveMainKey = keyEnum
								activeKeysCounted = { [keyEnum] = true }
								_ActiveBindCount = 1
								fire(true, true)
							else
								_ToggleState = not _ToggleState
								self.Active = _ToggleState
								_ActiveMainKey = keyEnum
								activeKeysCounted = { [keyEnum] = true }
								fire(_ToggleState, true)
							end

							_TapCount = 0
							return
						end

						if blockedPresses[keyEnum] then
							blockedPresses[keyEnum] = nil
							fire(false, false)
							return
						end

						if not activeKeysCounted[keyEnum] then
							return
						end

						if self.Hold then
							activeKeysCounted = {}
							_ActiveBindCount = 0
							_ActiveMainKey = nil
							_ToggleState = false
							fire(false, false)

							tryConsumeBuffer()
							return
						end
						if _TapCount == 0 then
							fire(_ToggleState, false)
						end
						if keyEnum == _ActiveMainKey then
							_ActiveMainKey = nil
							tryConsumeBuffer()
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
		scheduleRebuild()
	end

	function self:SetUIButton(button: GuiButton?)
		self.UIButton = button
		self:AddBind(Enum.KeyCode.Unknown)
		scheduleRebuild()
	end

	function self:SetCooldown(cooldown: number)
		self.Cooldown = math.max(0, cooldown)
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
	end

	function self:SetEnabled(enabled: boolean)
		self.Enabled = enabled

		if not enabled and self.Active then
			table.clear(modifiersState)
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

	function self:SetInputBufferEnabled(enabled: boolean)
		self.InputBufferEnabled = enabled
	end

	function self:SetInputBufferTime(t: number)
		t = math.max(0, t)
		self.InputBufferTime = t
	end

	function self:GetBinds(): {IAS.Bind}
		return deepCloneBinds(self.Binds)
	end

	function self:AddBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		if not isValidKeyCode(mainKey) then return end

		local modifiers = {}

		local seen: {[Enum.KeyCode]: boolean} = {}
		for i = 1, select("#", ...) do
			local mod = select(i, ...)
			if mod and isValidKeyCode(mod) and mod ~= mainKey and not seen[mod] then
				seen[mod] = true
				table.insert(modifiers, mod)
			end
		end

		for _, existing in self.Binds do
			if existing.KeyCode == mainKey and modifiersEqualSet(existing.Modifier, modifiers) then
				return
			end
		end

		table.insert(self.Binds, { KeyCode = mainKey, Modifier = modifiers })
		scheduleRebuild()
	end

	function self:SetBinds(binds: {IAS.Bind})
		local validBinds: {IAS.Bind} = {}
		for _, bind in binds do
			if isValidKeyCode(bind.KeyCode) then
				local validMods: {Enum.KeyCode?} = {}
				local seen: {[Enum.KeyCode]: boolean} = {}
				for _, mod in bind.Modifier do
					if mod and isValidKeyCode(mod) and not seen[mod] and mod ~= bind.KeyCode then
						seen[mod] = true
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

		if isValidKeyCode(newMain) then
			local cleanedMods: {Enum.KeyCode?} = {}
			local seen: {[Enum.KeyCode]: boolean} = {}
			if newMods then
				for _, m in newMods do
					if m and isValidKeyCode(m) and m ~= newMain and not seen[m] then
						seen[m] = true
						table.insert(cleanedMods, m)
					end
				end
			end
			table.insert(self.Binds, { KeyCode = newMain, Modifier = cleanedMods })
			scheduleRebuild()
		end
	end

	function self:RemoveBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		local modifiers: {Enum.KeyCode?} = {}
		local seen: {[Enum.KeyCode]: boolean} = {}
		for i = 1, select("#", ...) do
			local m = select(i, ...)
			if m and isValidKeyCode(m) and not seen[m] then
				seen[m] = true
				table.insert(modifiers, m)
			end
		end

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
		table.clear(stateConnections)

		self.Activated:DisconnectAll()

		if InputContext and InputContext.Parent then
			for _, child in InputContext:GetChildren() do child:Destroy() end
			InputContext:Destroy()
		end

		activeBinds[self.Name] = nil

		_PrevHold = nil
		_PrevBindsHash = nil
		_PrevUIButton = nil
		_ToggleState = nil
		_CooldownUntil = nil
		_LastTapTime = nil
		_TapCount = nil
		_ActiveBindCount = nil
		_ActiveMainKey = nil
		_Buffered = nil
		_BufferedTime = nil
		_BufferedKey = nil
		modifiersState = nil
		stateConnections = nil
		modifierToBindsMap = nil
		mainKeysDown = nil
		activeKeysCounted = nil
		blockedPresses = nil
		rebuildScheduled = nil
		self = nil
	end

	activeBinds[name] = self
	scheduleRebuild()
	return self
end

function IIAS.get(name: string): IAS.Object?
	return activeBinds[name]
end

function IIAS.getAll(): {[string]: IAS.Object}
	return activeBinds
end

function IIAS.newContext(name: string)
	if not IIAS.contextedBinds[name] then
		IIAS.contextedBinds[name] = {
			Enabled = true,
			Members = {},
		}
	end
end

function IIAS.addContext(name: string, ...: IAS.Object)
	IIAS.newContext(name)
	local context = IIAS.contextedBinds[name].Members
	for _, obj in { ... } do
		context[obj.Name] = true
	end
end

function IIAS.enableContext(name: string, enabled: boolean)
	local context = IIAS.contextedBinds[name]
	if not context then return end

	for bindName in context.Members do
		local obj = IIAS.get(bindName)
		if obj then
			obj:SetEnabled(enabled)
		end
	end
	
	context.Enabled = enabled
end

function IIAS.isContextEnabled(name: string)
	if not IIAS.contextedBinds[name] then return false end
	return IIAS.contextedBinds[name].Enabled
end

function IIAS.removeFromContext(name: string, bind: IAS.Object)
	local context = IIAS.contextedBinds[name]
	if not context then return end
	context.Members[bind.Name] = nil
end

function IIAS.removeContext(name: string)
	IIAS.contextedBinds[name] = nil
end

function IIAS.clearContexts()
	IIAS.contextedBinds = {}
end

return IIAS :: IAS.IllusionIAS
