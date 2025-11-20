--!strict
-- IllusionIAS.luau
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

local function bindsEqual(a: {IAS.Bind}, b: {IAS.Bind}): boolean
	if #a ~= #b then return false end
	for i = 1, #a do
		local A, B = a[i], b[i]
		if A.KeyCode ~= B.KeyCode then return false end
		if #A.Modifier ~= #B.Modifier then return false end
		for m = 1, #A.Modifier do if A.Modifier[m] ~= B.Modifier[m] then return false end end
	end
	return true
end

local function createAction(key, InputContext: InputContext, UIButton: GuiButton?)
	local action = Instance.new("InputAction")
	action.Name = key.Name

	local binding = Instance.new("InputBinding")
	binding.KeyCode = key

	if UIButton then binding.UIButton = UIButton end

	binding.Parent = action
	action.Parent = InputContext
end

local function clearConnections(stateConnections: {RBXScriptConnection})
	for i = 1, #stateConnections do
		local c = stateConnections[i]
		if c and c.Connected then c:Disconnect() end
		stateConnections[i] = nil
	end
end

local I2AS = {}
local activeBinds: { [string]: IAS.Object } = {}

function I2AS.new(name): IAS.Object
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
		
		Activated = Signal.makeSignal(),
		
		SetHold = function() end,
		SetUIButton = function() end,
		SetBinds = function() end,
		SetCooldown = function() end,

		AddBind = function() end,
		SetBind = function() end,
		RemoveBind = function() end,
		EditBind = function() end,
		ClearBinds = function() end,
		
		Destroy = function() end,
	}

	local modifiersState = {}
	local stateConnections: { RBXScriptConnection } = {}
	local rebuildScheduled = false
	
	local function fire(active, pressed)
		if active then
			local now = os.clock()
			if self.Cooldown > 0 and now < self._CooldownUntil then return end
			if self.Cooldown > 0 then self._CooldownUntil = now + self.Cooldown end
		end

		self.Active = active
		self.Activated:Fire(active, pressed)
	end

	local function rebuild()
		clearConnections(stateConnections)
		for _, child in InputContext:GetChildren() do child:Destroy() end

		for _, bind in self.Binds do
			for _, modKey in bind.Modifier do
				if bind.KeyCode == modKey then
					warn(`IAS: Modifier cannot be equal to KeyCode in "{self.Name}"`)
					return
				end
			end

			createAction(bind.KeyCode, InputContext, self.UIButton)
			
			for _, mod in bind.Modifier do
				if typeof(mod) == "EnumItem" and mod.EnumType == Enum.KeyCode then
					createAction(mod, InputContext, self.UIButton)
				end
			end
		end

		local bindLookup: { [Enum.KeyCode]: IAS.Bind } = {}
		for _, b in self.Binds do bindLookup[b.KeyCode] = b end

		for _, action in InputContext:GetChildren() do
			if not action:IsA("InputAction") then continue end

			local keyEnum: Enum.KeyCode? = (Enum.KeyCode::any)[action.Name]
			if not keyEnum or typeof(keyEnum) ~= "EnumItem" or keyEnum.EnumType ~= Enum.KeyCode then continue end

			local bindData = bindLookup[keyEnum]
			local isModifier = not bindData

			if isModifier then
				local rbxConnection = action.StateChanged:Connect(function(pressed: boolean)
					modifiersState[keyEnum] = pressed

					if self.Hold and not pressed then
						for _, b in self.Binds do
							if table.find(b.Modifier, keyEnum) and self.Active then
								fire(false, false)
								break
							end
						end
					end
				end)
				
				table.insert(stateConnections, rbxConnection)
				continue
			end

			local rbxConnection = action.StateChanged:Connect(function(pressed: boolean)
				if not bindData then return end

				for _, modKey in bindData.Modifier do if modKey and not modifiersState[modKey] then return end end

				if self.Hold then
					local allActive = true
					for _, modKey in bindData.Modifier do
						if modKey and not modifiersState[modKey] then
							allActive = false
							break
						end
					end

					if not allActive and self.Active then 
						fire(false, false) 
						return 
					end

					fire(pressed, pressed)
					return
				end

				if pressed then self._ToggleState = not self._ToggleState end

				fire(self._ToggleState, pressed)
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
				and self.Cooldown == self._PrevCooldown) then

				self._PrevBinds = table.clone(self.Binds)
				self._PrevUIButton = self.UIButton
				self._PrevHold = self.Hold
				self._PrevCooldown = self.Cooldown

				rebuild()
			end
			
			rebuildScheduled = false
		end)
	end

	function self:SetHold(hold)
		self.Hold = hold
		scheduleRebuild()
	end

	function self:SetUIButton(button)
		self.UIButton = button
		scheduleRebuild()
	end

	function self:SetBinds(binds)
		self.Binds = binds
		scheduleRebuild()
	end
	
	function self:SetCooldown(cooldown)
		self.Cooldown = (cooldown > 0) and cooldown or 0
		scheduleRebuild()
	end
	
	function self:AddBind(mainKey, ...: Enum.KeyCode?)
		local modifiers = {}
		local var = { ... }
		
		for i = 1, #var do table.insert(modifiers, var[i]) end
		
		for _, m in modifiers do if m == mainKey then return end end
		
		table.insert(self.Binds, { KeyCode = mainKey, Modifier = modifiers })
		scheduleRebuild()
	end

	function self:SetBind(mainKey, ...: Enum.KeyCode?)
		table.clear(self.Binds)
		self:AddBind(mainKey, ...)
	end

	function self:ClearBinds()
		table.clear(self.Binds)
		scheduleRebuild()
	end

	function self:RemoveBind(mainKey, ...: Enum.KeyCode?)
		local targetMods = {}
		local var = { ... }
		
		for i = 1, #var do table.insert(targetMods, var[i]) end

		for i = #self.Binds, 1, -1 do
			local b = self.Binds[i]
			if b.KeyCode == mainKey and #b.Modifier == #targetMods then
				local same = true
				for j = 1, #targetMods do
					if b.Modifier[j] ~= targetMods[j] then 
						same = false 
						break
					end 
				end
				if same then
					table.remove(self.Binds, i)
					scheduleRebuild()
					return
				end
			end
		end
	end

	function self:EditBind(oldMain, oldMods, newMain, newMods)
		local oldModifiers = {}
		for i = 1, #oldMods do table.insert(oldModifiers, oldMods[i]) end

		local newModifiers = {}
		for i = 1, #newMods do table.insert(newModifiers, newMods[i]) end

		for i = #self.Binds, 1, -1 do
			local b = self.Binds[i]
			if b.KeyCode == oldMain and #b.Modifier == #oldModifiers then
				local same = true
				for j = 1, #oldModifiers do 
					if b.Modifier[j] ~= oldModifiers[j] then 
						same = false 
						break 
					end 
				end

				if same then
					table.remove(self.Binds, i)
					break
				end
			end
		end

		table.insert(self.Binds, { KeyCode = newMain, Modifier = newModifiers })
		scheduleRebuild()
	end

	function self:Destroy()
		clearConnections(stateConnections)
		table.clear(modifiersState)

		if InputContext.Parent then InputContext:Destroy() end

		activeBinds[self.Name] = nil
	end

	activeBinds[name] = self
	return self
end

function I2AS.Get(name: string?): {[string]: IAS.Object} | IAS.Object?
	return name and activeBinds[name] or activeBinds
end

return I2AS
