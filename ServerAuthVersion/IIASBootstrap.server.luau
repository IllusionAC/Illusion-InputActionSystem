--!strict
-- InputAuthorityBootstrap.luau
-- Place this in ServerScriptService

local Players = game:GetService("Players")

local MAX_CONTEXTS = 16
local MAX_ACTIONS_PER_CONTEXT = 4

local function createBindingPool(action: InputAction)
	local binding = Instance.new("InputBinding")
	binding.KeyCode = Enum.KeyCode.Unknown
	binding:SetAttribute("InUse", false)
	binding.Parent = action
end

local function createActionPool(context: InputContext)
	for i = 1, MAX_ACTIONS_PER_CONTEXT do
		local action = Instance.new("InputAction")
		action.Name = "Action_" .. i
		action.Enabled = true
		action:SetAttribute("InUse", false)
		action.Parent = context

		createBindingPool(action)
	end
end

local function createContextPool(root: Folder)
	for i = 1, MAX_CONTEXTS do
		local context = Instance.new("InputContext")
		context.Name = "Context_" .. i
		context.Enabled = true
		context.Priority = 1000
		context.Sink = false
		context.Parent = root

		createActionPool(context)
	end
end

Players.PlayerAdded:Connect(function(player)
	local InputContexts = player:WaitForChild("InputContexts")

	local contexts = Instance.new("Folder")
	contexts.Name = "IIASContexts"
	contexts.Parent = InputContexts

	createContextPool(contexts)
end)
