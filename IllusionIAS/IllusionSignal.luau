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
		local head: IAS.Node? = nil

		local function createConnection(node: IAS.Node, prev: IAS.Node?): IAS.IAScriptConnection
			local connected = true

			local conn: IAS.IAScriptConnection = {
				Connected = true,
				Disconnect = function(self)
					if not connected then return end
					connected = false
					self.Connected = false

					if head == node then
						head = node.next
						return
					end

					local current = head
					while current and current.next ~= node do
						current = current.next
					end

					if current then
						current.next = node.next
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

				conn = self:Connect(function(...)
					if fired then return end
					fired = true
					conn:Disconnect()
					fn(...)
				end)

				return conn
			end,

			Wait = function(self: IAS.IAScriptSignal): ...any
				local thread = coroutine.running()
				local conn: IAS.IAScriptConnection
				local args: {any}? = nil

				conn = self:Connect(function(...)
					conn:Disconnect()
					args = table.pack(...)
					task.spawn(thread)
				end)

				coroutine.yield()
				return table.unpack(args or {})
			end,

			Fire = function(self: IAS.IAScriptSignal, ...: any)
				local node = head
				while node do
					node.fn(...)
					node = node.next
				end
			end,

			DisconnectAll = function(self: IAS.IAScriptSignal)
				head = nil
			end,
		}

		return Signal
	end
}
