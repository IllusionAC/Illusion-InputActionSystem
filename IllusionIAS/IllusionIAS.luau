--!strict
-- IllusionIAS.luau (fixed)
--[[
///////////////////////////////////////////////
\\      Illusion's InputActionSystem         \\
//  Custom-made Module using the new IAS     //
\\ Metatable-free | Closure based OOP Module \\
//  More informations on the DevForum post   //
\\              By Illusion                  \\
///////////////////////////////////////////////
]]--

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
		
		Cooldown = 0,
		_PrevCooldown = 0,
		_CooldownUntil = 0,

		TapRequired = 1,
		TapWindow = 0,
		_PrevTapRequired = 1,
		_PrevTapWindow = 0,
		
		_LastTapTime = 0,
		_TapCount = 0,
		
		Activated = Signal.makeSignal(),
		
		SetHold = function() end,
		SetUIButton = function() end,
		SetBinds = function() end,
		SetCooldown = function() end,
		SetTapActivation = function() end,

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
	
	local function fire(active, pressed)
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

		local bindLookup: { [Enum.KeyCode]: {IAS.Bind} } = {}
		local modifierKeysSet: { [Enum.KeyCode]: boolean } = {}

		for _, b in self.Binds do
			bindLookup[b.KeyCode] = bindLookup[b.KeyCode] or {}
			table.insert(bindLookup[b.KeyCode], b)
			for _, m in b.Modifier do
				if m and typeof(m) == "EnumItem" and m.EnumType == Enum.KeyCode then modifierKeysSet[m] = true end
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

					if self.Hold and not pressed then
						for _, bindsForKey in bindLookup do
							for _, b in bindsForKey do
								for _, modKey in b.Modifier do
									if modKey == keyEnum and self.Active then
										fire(false, false)
										break
									end
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
						if now - self._LastTapTime > self.TapWindow then self._TapCount = 0 end

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
				elseif pressed and not _anyBindSatisfied then return
				else fire(self._ToggleState, pressed) 
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
		self.Cooldown = (cooldown > 0) and cooldown or 0
		scheduleRebuild()
	end

	function self:SetTapActivation(requiredTaps: number, tapWindow: number)
		requiredTaps = (requiredTaps >= 1) and requiredTaps or 1
		tapWindow = (tapWindow > 0) and tapWindow or 0

		self.TapRequired = requiredTaps
		self.TapWindow = tapWindow

		self._TapCount = 0
		self._LastTapTime = 0
		scheduleRebuild()
	end
	
	function self:AddBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		local modifiers = {}
		local var = { ... }
		
		for i = 1, #var do table.insert(modifiers, var[i]) end
		for _, m in modifiers do if m == mainKey then return end end

		for _, existing in self.Binds do
			if existing.KeyCode == mainKey and modifiersEqualSet(existing.Modifier, modifiers) then return end
		end
		
		table.insert(self.Binds, { KeyCode = mainKey, Modifier = modifiers })
		scheduleRebuild()
	end
	
	function self:SetBinds(binds: {IAS.Bind})
		self.Binds = deepCloneBinds(binds)
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
		scheduleRebuild()
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

		if InputContext and InputContext.Parent then
			for _, child in InputContext:GetChildren() do child:Destroy() end
			InputContext:Destroy()
		end
		
		activeBinds[self.Name] = nil
	end

	activeBinds[name] = self
	return self
end

function I2AS.Get(name: string?): {[string]: IAS.Object} | IAS.Object?
	return name and activeBinds[name] or activeBinds
end

return I2AS
