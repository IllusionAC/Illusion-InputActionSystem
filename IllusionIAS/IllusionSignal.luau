--!strict
--IllusionSignal.luau
--[[ 
  //////////////////////
 //  Illusion Signal //
//////////////////////
]]

local IAS = require("./TypeDefinition")

return {
	new = function(): IAS.IAScriptSignal
		local head: IAS.Node?

		local function createConnection(node: IAS.Node): IAS.IAScriptConnection
			local connected = true

			local conn: IAS.IAScriptConnection
			conn = {
				Connected = true,
				Disconnect = function(self: IAS.IAScriptConnection)
					if not connected then return end
					connected = false
					self.Connected = false
					node.fn = nil

					if head == node then
						head = node.next
						node.next = nil
						return
					end

					local current = head
					while current and current.next ~= node do
						current = current.next
					end

					if current then
						current.next = node.next
						node.next = nil
					end
				end,
			}

			return conn
		end

		local Signal: IAS.IAScriptSignal = {
			Connect = function(self: IAS.IAScriptSignal, fn: IAS.func): IAS.IAScriptConnection
				local node: IAS.Node = {
					fn = fn,
					next = head,
				}

				head = node
				return createConnection(node)
			end,

			Once = function(self: IAS.IAScriptSignal, fn: IAS.func): IAS.IAScriptConnection
				local fired = false
				local conn: IAS.IAScriptConnection

				conn = self:Connect(function(active: IAS.variant, pressed: boolean?)
					if fired then return end
					fired = true
					if conn then
						conn:Disconnect()
					end
					fn(active, pressed)
				end)

				return conn
			end,

			Wait = function(self: IAS.IAScriptSignal): (IAS.variant, boolean?)
				local thread = coroutine.running()
				local conn: IAS.IAScriptConnection

				conn = self:Connect(function(active: IAS.variant, pressed: boolean?)
					if conn then
						conn:Disconnect()
					end
					task.spawn(thread, active, pressed)
				end)

				return coroutine.yield()
			end,

			Fire = function(self: IAS.IAScriptSignal, active: IAS.variant, pressed: boolean?)
				local node = head
				while node do
					local fn = node.fn
					node = node.next
					if fn then
						task.spawn(fn, active, pressed)
					end
				end
			end,

			DisconnectAll = function(self: IAS.IAScriptSignal)
				local node = head
				while node do
					node.fn = nil
					local nextNode = node.next
					node.next = nil
					node = nextNode
				end
				head = nil
			end,
		}

		return Signal
	end,
}
