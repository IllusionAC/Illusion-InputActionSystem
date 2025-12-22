--!strict
--IllusionIASAuth.luau
--[[
///////////////////////////////////////////////
\\      Illusion's InputActionSystem         \\
//  Custom-made Module using the new IAS     //
\\ Metatable-free | Closure based OOP Module \\
//  More informations on the DevForum post   //
\\              By Illusion                  \\
///////////////////////////////////////////////
]]

local Players = game:GetService("Players")

local IAS = require("@self/TypeDefinition")
local IASignal = require("@self/IllusionSignal")

local player = Players.LocalPlayer

local ContextFolder = player:WaitForChild("InputContexts")
local IIASContexts = ContextFolder:FindFirstChild("IIASContexts")

local function acquireContext(name: string): InputContext
	for _, ctx in IIASContexts:GetChildren() do
		if ctx:IsA("InputContext") and not ctx:GetAttribute("InUse") then
			ctx:SetAttribute("InUse", true)
			ctx.Name = name
			ctx.Enabled = true
			return ctx
		end
	end
	error("InputContext pool exhausted")
end

local function releaseContext(ctx: InputContext)
	for _, action in ctx:GetChildren() do
		if action:IsA("InputAction") then
			action:SetAttribute("InUse", false)
			action.Enabled = false

			for _, binding in action:GetChildren() do
				if binding:IsA("InputBinding") then
					binding:SetAttribute("InUse", false)
					binding.KeyCode = Enum.KeyCode.Unknown
					binding.UIButton = nil
				end
			end
		end
	end
	ctx:SetAttribute("InUse", false)
	ctx.Enabled = false
end

local function acquireAction(ctx: InputContext): InputAction?
	for _, action in ctx:GetChildren() do
		if action:IsA("InputAction") and not action:GetAttribute("InUse") then
			action:SetAttribute("InUse", true)
			action.Enabled = true
			return action
		end
	end
	return nil
end

local function acquireBinding(action: InputAction): InputBinding?
	for _, binding in action:GetChildren() do
		if binding:IsA("InputBinding") and not binding:GetAttribute("InUse") then
			binding:SetAttribute("InUse", true)
			return binding
		end
	end
	return nil
end

local function isValidKeyCode(key: any): boolean
	return typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode
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

local function pickBestSatisfiedBind(bindList: {IAS.Bind}, modifiersState: { [Enum.KeyCode]: boolean })
	local best, count = nil, -1
	for _, bind in bindList do
		local ok = true
		local c = 0
		for _, m in bind.Modifier do
			if m then
				c += 1
				if not modifiersState[m] then
					ok = false
					break
				end
			end
		end
		if ok and c > count then
			best, count = bind, c
		end
	end
	return best
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

local IIAS = {}
local activeBinds: {[string]: IAS.Object} = {}
IIAS.contextedBinds = {} :: {[string]: {Enabled: boolean, Members: {[string]: boolean}}}

function IIAS.new(name: string): IAS.Object
	if activeBinds[name] then
		return activeBinds[name]
	end

	local context = acquireContext(name)
	local stateConnections: {RBXScriptConnection} = {}

	local modifiersState: { [Enum.KeyCode]: boolean } = {}
	local mainKeysDown: { [Enum.KeyCode]: boolean } = {}
	local activeKeysCounted: { [Enum.KeyCode]: boolean } = {}
	local blockedPresses: { [Enum.KeyCode]: boolean } = {}

	local _CooldownUntil = 0
	local _TapCount = 0
	local _LastTapTime = 0
	local _ToggleState = false
	local _ActiveMainKey: Enum.KeyCode? = nil

	local _Buffered = false
	local _BufferedKey: Enum.KeyCode? = nil
	local _BufferedTime = 0


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
			if self.Cooldown > 0 then
				_CooldownUntil = now + self.Cooldown
			end
			fire(true, true)
			return true
		else
			if self.Cooldown > 0 then
				_CooldownUntil = now + self.Cooldown
			end
			_ToggleState = not _ToggleState
			self.Active = _ToggleState
			_ActiveMainKey = keyEnum
			activeKeysCounted = { [keyEnum] = true }
			fire(_ToggleState, true)
			return true
		end
	end

	local function clearConnections()
		for _, c in stateConnections do
			if c.Connected then c:Disconnect() end
		end
		table.clear(stateConnections)
	end

	local function rebuild()
		clearConnections()

		table.clear(modifiersState)
		table.clear(mainKeysDown)
		table.clear(activeKeysCounted)
		table.clear(blockedPresses)

		_TapCount = 0
		_LastTapTime = 0
		_ActiveMainKey = nil
		_Buffered = false

		for _, action in context:GetChildren() do
			if action:IsA("InputAction") then
				action:SetAttribute("InUse", false)
				action.Enabled = false

				for _, binding in action:GetChildren() do
					if binding:IsA("InputBinding") then
						binding:SetAttribute("InUse", false)
						binding.KeyCode = Enum.KeyCode.Unknown
						binding.UIButton = nil
					end
				end
			end
		end

		local bindLookup = {}
		local modifierKeys = {}

		for _, bind in self.Binds do
			bindLookup[bind.KeyCode] = bindLookup[bind.KeyCode] or {}
			table.insert(bindLookup[bind.KeyCode], bind)

			for _, m in bind.Modifier do
				if m then modifierKeys[m] = true end
			end
		end

		for mod in modifierKeys do
			local action = acquireAction(context)
			if not action then break end

			action.Name = mod.Name
			local binding = acquireBinding(action)
			if not binding then continue end
			binding.KeyCode = mod

			local conn = action.StateChanged:Connect(function(pressed)
				modifiersState[mod] = pressed
			end)
			table.insert(stateConnections, conn)
		end

		for key, bindList in bindLookup do
			local action = acquireAction(context)
			if not action then break end

			action.Name = key.Name
			local binding = acquireBinding(action)
			if not binding then continue end
			binding.KeyCode = key

			if key == Enum.KeyCode.Unknown and self.UIButton then
				binding.UIButton = self.UIButton
			end

			local conn = action.StateChanged:Connect(function(pressed: boolean)
				mainKeysDown[key] = pressed
				if not self.Enabled then return end

				local isUIButton = (key == Enum.KeyCode.Unknown)
				local bestBind = pickBestSatisfiedBind(bindList, modifiersState)
				local bindSatisfied = (bestBind ~= nil)

				local now = time()

				if pressed then
					if _ActiveMainKey and _ActiveMainKey ~= key then
						if self.InputBufferEnabled then
							_Buffered = true
							_BufferedTime = now
							_BufferedKey = key
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
						blockedPresses[key] = true
						return
					end

					if self.Cooldown > 0 then
						_CooldownUntil = now + self.Cooldown
					end

					if self.Hold then
						_ActiveMainKey = key
						activeKeysCounted = { [key] = true }
						fire(true, true)
					else
						_ToggleState = not _ToggleState
						self.Active = _ToggleState
						_ActiveMainKey = key
						activeKeysCounted = { [key] = true }
						fire(_ToggleState, true)
					end

					_TapCount = 0
					return
				end

				if blockedPresses[key] then
					blockedPresses[key] = nil
					fire(false, false)
					return
				end

				if not activeKeysCounted[key] then
					return
				end

				if self.Hold then
					activeKeysCounted = {}
					_ActiveMainKey = nil
					_ToggleState = false
					fire(false, false)

					tryConsumeBuffer()
					return
				end

				if _TapCount == 0 then
					fire(_ToggleState, false)
				end

				if key == _ActiveMainKey then
					_ActiveMainKey = nil
					tryConsumeBuffer()
				end
			end)

			table.insert(stateConnections, conn)
		end
	end
	
	function self:SetHold(v: boolean)
		self.Hold = v
		rebuild()
	end

	function self:SetUIButton(btn: GuiButton?)
		self.UIButton = btn
		self:AddBind(Enum.KeyCode.Unknown)
		rebuild()
	end
	
	function self:SetCooldown(v: number)
		self.Cooldown = math.max(0, v)
	end

	function self:ResetCooldown()
		_CooldownUntil = 0
	end

	function self:SetTapActivation(r, w)
		self.TapRequired = math.max(1, r)
		self.TapWindow = math.max(0, w)
		_TapCount = 0
		_LastTapTime = 0
	end

	function self:SetEnabled(v: boolean)
		self.Enabled = v

		if not v and self.Active then
			table.clear(modifiersState)
			self.Active = false
			self.Activated:Fire(false, false)
		end

		context.Enabled = v
	end
	
	function self:IsEnabled(): boolean
		return self.Enabled
	end

	function self:SetPriority(n: number)
		self.Priority = n
		context.Priority = n
	end

	function self:GetPriority()
		return self.Priority
	end

	function self:SetSink(b: boolean)
		self.Sink = b
		context.Sink = b
	end
	
	function self:GetSink()
		return self.Sink
	end

	function self:SetInputBufferEnabled(v: boolean)
		self.InputBufferEnabled = v
	end

	function self:SetInputBufferTime(t: number)
		self.InputBufferTime = math.max(0, t)
	end

	function self:GetBinds(): {IAS.Bind}
		return deepCloneBinds(self.Binds)
	end
	
	function self:AddBind(main: Enum.KeyCode, ...: Enum.KeyCode?)
		if not isValidKeyCode(main) then return end
		local mods: {Enum.KeyCode?} = {}
		for i = 1, select("#", ...) do
			local m: Enum.KeyCode? = select(i, ...)
			if isValidKeyCode(m) and m ~= main then
				table.insert(mods, m)
			end
		end
		table.insert(self.Binds, { KeyCode = main, Modifier = mods })
		rebuild()
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
			rebuild()
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
		clearConnections()
		self.Activated:DisconnectAll()
		releaseContext(context)
		activeBinds[name] = nil
	end

	activeBinds[name] = self
	rebuild()
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

return IIAS:: IAS.IllusionIAS
