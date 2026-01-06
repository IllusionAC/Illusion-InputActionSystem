--!strict
--IllusionIAS.luau
--[[
////////////////////////////////////////////////
\\       Illusion's InputActionSystem        //
//          Input Manager using IAS          \\
//   More informations on the DevForum post  //
\\                By Illusion                \\
///////////////////////////////////////////////
]]

local IAS = require("@self/TypeDefinition")
local IASignal = require("@self/IllusionSignal")
local BindUtils = require("@self/BindUtils")

local function getBindFolder()
	local existing = script:FindFirstChildOfClass("Folder")
	if existing then return existing end

	local folder = Instance.new("Folder")
	folder.Name = "BindFolder"
	folder.Parent = script
	return folder
end

local function instanceSetup(name, inputType, InputContext: InputContext): (InputAction, InputBinding)
	local InputAction = Instance.new("InputAction")
	InputAction.Name = name
	InputAction.Type = inputType
	InputAction.Parent = InputContext

	local InputBinding = Instance.new("InputBinding")
	InputBinding.Parent = InputAction
	
	return InputAction, InputBinding
end

local function instanceDeletion(name, InputContext: InputContext)
	local inputAction = InputContext:FindFirstChild(name)
	if inputAction then
		inputAction:Destroy()
	end
end

local function valueOfVariantGivesPressed(variant: boolean | number | Vector2 | Vector3): boolean
	if typeof(variant) == "boolean" then
		return variant
	elseif typeof(variant) == "number" then
		return variant ~= 0
	elseif typeof(variant) == "Vector2" then
		return variant ~= Vector2.zero
	else
		return variant ~= Vector3.zero
	end
end

local function pickBestSatisfiedBind(bindList: {{BindName: string, KeyCode: Enum.KeyCode, Modifiers: {Enum.KeyCode?}}}, modifiersState: { [Enum.KeyCode]: boolean })
	local best = nil
	local bestCount = -1

	for _, bind in bindList do
		local ok = true
		local count = 0

		for _, mod in bind.Modifiers do
			if not mod then continue end
			if not modifiersState[mod] then
				ok = false
				break
			end
			count += 1
		end

		if ok and count > bestCount then
			best = bind
			bestCount = count
		end
	end

	return best
end

local IIAS = {}
IIAS.contextedBinds = {} :: {[string]: {Enabled: boolean, Members: {[string]: boolean}}}

local activeBinds: { [string]: IAS.Object } = {}

function IIAS.new(name: string, InputType: Enum.InputActionType?): IAS.Object
	if activeBinds[name] then return activeBinds[name] end
	local InputType = InputType or Enum.InputActionType.Bool
		
	local InputContext: InputContext? = Instance.new("InputContext")
	if not InputContext then return {}::IAS.Object end
	InputContext.Name = name
	InputContext.Parent = getBindFolder()

	local MainName = "MainAction"
	
	local self: IAS.Object = {
		Name = name,

		Hold = true,

		Binds = {
			MainAction = {
				KeyCode = Enum.KeyCode.Unknown, 
				Modifier = {}
			},
			
			UIButton = {
				KeyCode = Enum.KeyCode.Unknown, 
				Modifier = {}
			},
		},

		UIButton = nil,

		Active = false,

		Enabled = true,
		Priority = 1000,
		Sink = false,
		
		Scale = 1,
		VectorScale = InputType == Enum.InputActionType.Direction2D and Vector2.one or Vector3.one,
		ResponseCurve = 1,

		PressedThreshold = 0.5,
		ReleasedThreshold = 0.2,

		Cooldown = 0,

		TapRequired = 1,
		TapWindow = 0,

		InputBufferEnabled = false,
		InputBufferTime = 0.15,

		Activated = IASignal.new(),

		SetHold = function() end,
		SetUIButton = function() end,
		SetTapActivation = function() end,
		SetCooldown = function() end,
		ResetCooldown = function() end,

		SetEnabled = function() end,
		IsEnabled = function(): boolean return true end,

		SetPriority = function() end,
		GetPriority = function(): number return 1000 end,

		SetSink = function() end,
		GetSink = function(): boolean return false end,
		
		SetScale = function() end,
		GetScale = function(): number return 0 end,
		
		SetVectorScale = function() end,
		GetVectorScale = function(): Vector2 | Vector3 return Vector2.zero end,
		
		SetResponseCurve = function() end,
		GetResponseCurve = function(): number return 0 end,
		
		SetPressedThreshold = function() end,
		GetPressedThreshold = function(): number return 0.5 end,

		SetReleasedThreshold = function() end,
		GetReleasedThreshold = function(): number return 0.2 end,
		
		GetState = function(): IAS.variant return 0 end,
		GetStates = function(): {[string]: IAS.variant} return {} end,

		SetInputBufferEnabled = function() end,
		SetInputBufferTime = function() end,
		
		ClearBinds = function() end,
		GetBinds = function(): {IAS.Binds} return {} end,
		AddBind = function() end,
		SetBind = function() end,
		RemoveBind = function() end,
		EditBind = function() end,

		SetCompositeDirections = function() end,

		Destroy = function(): boolean return false end,
	}

	local modifiersState: { [Enum.KeyCode]: boolean } = {}
	local stateConnections: { [string]: RBXScriptConnection } = {}

	local _PrevBinds = BindUtils.Clone(self.Binds)
	
	local _ToggleState = false
	local _CooldownUntil = 0
	local _LastTapTime = 0
	local _TapCount = 0
	local _ActiveBindCount = 0
	
	local _ActiveBindName: string? = nil
	local _ActiveMainKey: Enum.KeyCode? = nil

	local _Buffered = false
	local _BufferedTime = 0
	local _BufferedKey: Enum.KeyCode? = nil

	local mainKeysDown: { [Enum.KeyCode]: boolean } = {}
	local activeKeysCounted: { [Enum.KeyCode]: boolean } = {}
	local blockedPresses: { [Enum.KeyCode]: boolean } = {}
	local bindsByMainKey: {[Enum.KeyCode]: {{BindName: string, KeyCode: Enum.KeyCode, Modifiers: {Enum.KeyCode?}}}} = {}

	local function fire(value: IAS.variant, pressed: boolean)
		if not self.Enabled then return end
		self.Active = value
		self.Activated:Fire(value, pressed)
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
			_ActiveBindName = nil
			return true
		else
			if self.Cooldown > 0 then _CooldownUntil = now + self.Cooldown end
			_ToggleState = not _ToggleState
			_ActiveMainKey = keyEnum
			activeKeysCounted = { [keyEnum] = true }
			fire(_ToggleState, true)
			return true
		end
	end
	
	local childAddedConn: RBXScriptConnection? = InputContext.ChildAdded:Connect(function(child)
		if child:IsA("InputAction") then
			if child.Name:find("_Mod_") then
				stateConnections[child.Name] = child.StateChanged:Connect(function(bool: boolean)
					local binding = child:FindFirstChildOfClass("InputBinding")
					if not binding then return end

					modifiersState[binding.KeyCode] = bool
				end)
				
			elseif child.Name:find("AltAction") or child.Name == MainName or child.Name == "UIButton" then
				stateConnections[child.Name] = child.StateChanged:Connect(function(variant: IAS.variant)
					if not self.Enabled then return end
					
					local pressed = valueOfVariantGivesPressed(variant)
					
					local inputBinding = child:FindFirstChildOfClass("InputBinding")
					if not inputBinding then return end
					
					local keyEnum = inputBinding.KeyCode
					if keyEnum == Enum.KeyCode.Unknown and child.Name ~= "UIButton" then
						if InputType == Enum.InputActionType.Bool or InputType == Enum.InputActionType.ViewportPosition then
							return
						end
					end
					
					local now = time()
					
					if InputType == Enum.InputActionType.Bool then
						mainKeysDown[keyEnum] = pressed
						local bindList = bindsByMainKey[keyEnum]
						local bestBind = bindList and pickBestSatisfiedBind(bindList, modifiersState)
						
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

							if not bestBind then
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
								_ActiveBindName = bestBind and bestBind.BindName

								_ActiveMainKey = keyEnum
								activeKeysCounted = { [keyEnum] = true }
								_ActiveBindCount = 1
								fire(true, true)
							else
								_ActiveBindName = bestBind and bestBind.BindName
								
								_ToggleState = not _ToggleState
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
							_ActiveBindName = nil
							_ToggleState = false
							fire(false, false)

							tryConsumeBuffer()
							return							
						end
						
						if _TapCount == 0 and _ActiveBindName then
							fire(_ToggleState, false)
						end
						
						if keyEnum == _ActiveMainKey then
							_ActiveMainKey = nil
							_ActiveBindName = nil
							tryConsumeBuffer()
						end

						return
							
					elseif InputType == Enum.InputActionType.Direction1D or InputType == Enum.InputActionType.Direction2D or InputType == Enum.InputActionType.Direction3D then
						-- IMPORTANT:
						-- This section works but is not FINISHED
						-- You will be able to use it but without Hold, tapRequired or Cooldown.
						fire(variant, pressed)
					elseif InputType == Enum.InputActionType.ViewportPosition then
						if self.Cooldown > 0 and now < _CooldownUntil then
							fire(Vector2.zero, false)
							return
						end

						if self.Cooldown > 0 then
							_CooldownUntil = now + self.Cooldown
						end
						
						fire(variant, true)
						return
					end
				end)
			end
		end
	end)

	local childRemovedConn: RBXScriptConnection? = InputContext.ChildRemoved:Connect(function(child)
		if stateConnections[child.Name] then
			stateConnections[child.Name]:Disconnect()
			stateConnections[child.Name] = nil
		end
	end)
	
	local InputAction, InputBinding = instanceSetup(MainName, InputType, InputContext)
	local _, UIButtonBinding = instanceSetup("UIButton", Enum.InputActionType.Bool, InputContext)
	
	local rebuilding = false
	local destroyed = false
	local function rebuild()
		if rebuilding then return end
		if destroyed then return end
		rebuilding = true
								
		local isEqual, differences = BindUtils.CheckDifferences(_PrevBinds, self.Binds)
		
		table.clear(bindsByMainKey)
		table.clear(modifiersState)

		if not isEqual and differences then		
			local diffs = BindUtils.GetDifference(_PrevBinds, differences) :: {IAS.DiffList}

			for _, diff in diffs do
				if diff.ChangeType == "Modified" then
					if diff.OldKeyCode ~= diff.NewKeyCode and diff.NewKeyCode then
						InputBinding.KeyCode = diff.NewKeyCode
					end

					for _, key in diff.AddedModifiers do
						key = key or Enum.KeyCode.Unknown
						local _, modbinding = instanceSetup(`{MainName}_Mod_{key.Name}`, Enum.InputActionType.Bool, InputContext)
						modbinding.KeyCode = key
					end

					for _, key in diff.RemovedModifiers do
						instanceDeletion(`{MainName}_Mod_{(key or Enum.KeyCode.Unknown).Name}`, InputContext)
					end

				elseif diff.ChangeType == "Added" then
					local _, altbinding = instanceSetup(diff.BindName, InputType, InputContext)
					altbinding.KeyCode = diff.NewKeyCode or Enum.KeyCode.Unknown

					for _, key in diff.AddedModifiers do
						key = key or Enum.KeyCode.Unknown
						local _, altmodbinding = instanceSetup(`{diff.BindName}_Mod_{key.Name}`, Enum.InputActionType.Bool, InputContext)
						altmodbinding.KeyCode = key
					end

				elseif diff.ChangeType == "Removed" then
					instanceDeletion(diff.BindName, InputContext)

					for _, key in diff.RemovedModifiers do
						instanceDeletion(`{diff.BindName}_Mod_{(key or Enum.KeyCode.Unknown).Name}`, InputContext)
					end
				end
			end

			BindUtils.ApplyDifferences(_PrevBinds, differences)
			
			for bindName, bind in self.Binds do
				local mainKey = bind.KeyCode
				if not mainKey then continue end

				bindsByMainKey[mainKey] = bindsByMainKey[mainKey] or {}

				table.insert(bindsByMainKey[mainKey], {
					BindName = bindName,
					KeyCode = mainKey,
					Modifiers = table.clone(bind.Modifier),
				})

				for _, mod in bind.Modifier do
					if mod then
						modifiersState[mod] = false
					end
				end
			end

			_PrevBinds = BindUtils.Clone(self.Binds)
		end
					
		rebuilding = false
	end

	rebuild()
		
	function self:SetHold(bool: boolean)
		self.Hold = bool
	end

	function self:SetUIButton(button: GuiButton?)
		if InputType == Enum.InputActionType.Bool then
			self.UIButton = button
			UIButtonBinding.UIButton = self.UIButton
		end
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

		if not enabled then
			table.clear(modifiersState)
			_ActiveBindName = nil
			self.Activated:Fire(false, false)
		end

		InputContext.Enabled = self.Enabled
	end

	function self:IsEnabled()
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
	
	function self:SetScale(scale: number)
		self.Scale = scale
		InputBinding.Scale = self.Scale
	end
	
	function self:GetScale(): number
		return self.Scale
	end
	
	function self:SetVectorScale(vector: Vector2 | Vector3)
		self.VectorScale = vector
		if InputType == Enum.InputActionType.Direction2D then
			InputBinding.Vector2Scale = typeof(vector) == "Vector2" and vector or Vector2.one
		elseif InputType == Enum.InputActionType.Direction3D then
			InputBinding.Vector3Scale = typeof(vector) == "Vector3" and vector or Vector3.one
		end
	end

	function self:GetVectorScale(): Vector2 | Vector3
		return self.VectorScale
	end
	
	function self:SetInputBufferEnabled(enabled: boolean)
		self.InputBufferEnabled = enabled
	end
	
	function self:SetResponseCurve(curve: number)
		self.ResponseCurve = curve
		InputBinding.ResponseCurve = self.ResponseCurve
	end
	
	function self:GetResponseCurve(): number
		return self.ResponseCurve
	end
	
	function self:SetPressedThreshold(threshold: number)
		self.PressedThreshold = threshold
	end
	
	function self:GetPressedThreshold()
		return self.PressedThreshold
	end
	
	function self:SetReleasedThreshold(threshold: number)
		self.ReleasedThreshold = threshold
	end
	
	function self:GetReleasedThreshold()
		return self.ReleasedThreshold
	end

	function self:SetInputBufferTime(t: number)
		t = math.max(0, t)
		self.InputBufferTime = t
	end
	
	function self:GetState(): IAS.variant
		return InputAction:GetState()
	end
	
	function self:GetStates(): {[string]: IAS.variant}
		local newx: {[string]: IAS.variant} = {}
		for _, v in InputContext:GetChildren() do
			if v:IsA("InputAction") then
				newx[v.Name] = v:GetState()
			end
		end
		return newx
	end

	function self:ClearBinds()
		BindUtils.ResetBinds(self.Binds)
		rebuild()
	end
	
	function self:GetBinds(): IAS.Binds
		return BindUtils.Clone(self.Binds)
	end
	
	function self:AddBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		if mainKey == Enum.KeyCode.Unknown then
			return
		end

		local modifiers = { ... }

		for bindName, bind in self.Binds do
			if bind.KeyCode == mainKey then
				BindUtils.SetModifiers(self.Binds, bindName, modifiers)
				rebuild()
				return
			end
		end

		local mainBind = self.Binds[MainName]

		if mainBind and mainBind.KeyCode == Enum.KeyCode.Unknown then
			BindUtils.SetKeyCode(self.Binds, MainName, mainKey)
			BindUtils.SetModifiers(self.Binds, MainName, modifiers)
			rebuild()
			return
		end

		local index = 1
		local bindName

		repeat
			bindName = `AltAction{index}`
			index += 1
		until not self.Binds[bindName]

		BindUtils.AddBind(self.Binds, bindName, mainKey, modifiers)
		rebuild()
		return
	end
	
	function self:SetBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		self:ClearBinds()
		self:AddBind(mainKey, ...)
	end
	
	function self:RemoveBind(mainKey: Enum.KeyCode, ...: Enum.KeyCode?)
		if not mainKey then return end

		local targetMods = { ... }

		for bindName, bind in self.Binds do
			if bind.KeyCode ~= mainKey then
				continue
			end

			local equal = BindUtils.CheckDifferences(
				{ X = { KeyCode = mainKey, Modifier = bind.Modifier } },
				{ X = { KeyCode = mainKey, Modifier = targetMods } }
			)

			if not equal then
				continue
			end

			if bindName == "MainAction" then
				BindUtils.ResetKeyCode(self.Binds, "MainAction")
				BindUtils.ClearModifiers(self.Binds, "MainAction")
			else
				BindUtils.RemoveBind(self.Binds, bindName)
			end

			rebuild()
			return
		end
	end
	
	function self:EditBind(
		oldMain: Enum.KeyCode,
		oldMods: {Enum.KeyCode?}?,
		newMain: Enum.KeyCode,
		newMods: {Enum.KeyCode?}?
	)
		if not oldMain or not newMain then return end

		oldMods = oldMods or {}
		newMods = newMods or {}

		for bindName, bind in self.Binds do
			if bind.KeyCode ~= oldMain then
				continue
			end

			local equal = BindUtils.CheckDifferences(
				{ X = { KeyCode = oldMain, Modifier = bind.Modifier } },
				{ X = { KeyCode = oldMain, Modifier = oldMods } }
			)

			if not equal then
				continue
			end

			BindUtils.SetKeyCode(self.Binds, bindName, newMain)
			BindUtils.SetModifiers(self.Binds, bindName, newMods)

			rebuild()
			return
		end
	end

	function self:SetCompositeDirections(Up, Down, Left, Right, Forward, Backward)
		if InputType == Enum.InputActionType.Bool or InputType == Enum.InputActionType.ViewportPosition then return end
		InputBinding.Up = Up or Enum.KeyCode.Unknown
		InputBinding.Down = Down or Enum.KeyCode.Unknown
		InputBinding.Left = Left or Enum.KeyCode.Unknown
		InputBinding.Right = Right or Enum.KeyCode.Unknown
		InputBinding.Forward = Forward or Enum.KeyCode.Unknown
		InputBinding.Backward = Backward or Enum.KeyCode.Unknown
	end
	
	function self:Destroy()	
		destroyed = true
		for _, conn in stateConnections do
			if conn then
				conn:Disconnect()
			end
		end
		
		table.clear(stateConnections)
		
		if childAddedConn then
			childAddedConn:Disconnect()
			childAddedConn = nil
		end

		if childRemovedConn then
			childRemovedConn:Disconnect()
			childRemovedConn = nil
		end
		
		for _, context in IIAS.contextedBinds do
			context.Members[self.Name] = nil
		end
		
		for _, child in InputContext:GetChildren() do
			child:Destroy()
		end

		InputContext:Destroy()
		InputContext = nil
		
		self.Activated:DisconnectAll()

		activeBinds[name] = nil
		
		return true
	end

	activeBinds[name] = self
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

function IIAS.getContext(name: string)
	return IIAS.contextedBinds[name]
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

function IIAS.removeAllFromContext(name: string)
	IIAS.contextedBinds[name] = {
		Enabled = true,
		Members = {},
	}
end

function IIAS.removeContext(name: string)
	IIAS.contextedBinds[name] = nil
end

function IIAS.clearContexts()
	IIAS.contextedBinds = {}
end

return IIAS :: IAS.IllusionIAS
