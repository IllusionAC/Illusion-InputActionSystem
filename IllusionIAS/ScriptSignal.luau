--!strict
--ScriptSignal.luau
--[[ 
  /////////////////////////// 
 // Signal Factory Module // 
///////////////////////////
]]

local IAS = require("./TypeDefinition")

local function pack(active: boolean, pressed: boolean): { n: number, [number]: boolean }
	return {
		n = 2,
		[1] = active,
		[2] = pressed,
	}
end

return {
	new = function(): IAS.IAScriptSignal
		local head: IAS.Node? = nil
		local tail: IAS.Node? = nil

		local pool: { thread } = {}
		local poolSize = 4
		local running = 0

		local function createRunner(): thread
			return coroutine.create(function()
				while true do
					local fn: IAS.func, args: { [number]: boolean } = coroutine.yield()
					if not fn then break end

					pcall(fn, args[1], args[2])
				end
			end)
		end

		for i = 1, poolSize do
			table.insert(pool, createRunner())
		end

		local function acquire(): thread?
			local co = table.remove(pool)
			if co then running += 1 end
			return co
		end

		local function release(co: thread)
			running -= 1
			if #pool < poolSize then
				table.insert(pool, co)
			end
		end

		local function dispatchParallel(fn: IAS.func, active: boolean, pressed: boolean)
			local args = pack(active, pressed)
			local co = acquire()

			if co ~= nil then
				task.spawn(function()
					coroutine.resume(co, fn, args)
					release(co)
				end)
			else
				task.spawn(function()
					pcall(fn, active, pressed)
				end)
			end
		end

		local function createConnection(node: IAS.Node): IAS.IAScriptConnection
			local conn: IAS.IAScriptConnection = {
				Connected = true,
				Disconnect = function(self)
					if not self.Connected then return end
					self.Connected = false
					node.connected = false

					if head == node then
						head = node.next
						if head == nil then tail = nil end
						return
					end

					local prev = head
					while prev and prev.next ~= node do
						prev = prev.next
					end

					if prev then
						prev.next = node.next
						if tail == node then tail = prev end
					end
				end,
			}

			return conn
		end

		local Signal: IAS.IAScriptSignal = {

			Connect = function(self: IAS.IAScriptSignal, fn: IAS.func): IAS.IAScriptConnection
				local node: IAS.Node = {
					fn = fn,
					connected = true,
					parallel = false,
					next = nil,
				}

				if not head then
					head = node
					tail = node
				else
					(tail :: IAS.Node).next = node
					tail = node
				end

				return createConnection(node)
			end,

			ConnectParallel = function(self: IAS.IAScriptSignal, fn: IAS.func): IAS.IAScriptConnection
				local node: IAS.Node = {
					fn = fn,
					connected = true,
					parallel = true,
					next = nil,
				}

				if not head then
					head = node
					tail = node
				else
					(tail :: IAS.Node).next = node
					tail = node
				end

				return createConnection(node)
			end,

			Once = function(self: IAS.IAScriptSignal, fn: IAS.func): IAS.IAScriptConnection
				local fired = false
				local conn: IAS.IAScriptConnection

				conn = self:Connect(function(active, pressed)
					if fired then return end
					fired = true
					conn:Disconnect()

					pcall(fn, active, pressed)
				end)

				return conn
			end,

			Wait = function(self: IAS.IAScriptSignal): (boolean, boolean)
				local thread = coroutine.running()
				local a = false
				local b = false
				local yielded = false

				local conn: IAS.IAScriptConnection
				conn = self:Connect(function(active, pressed)
					if not conn.Connected then return end
					conn:Disconnect()

					a = active
					b = pressed

					if yielded then
						task.spawn(coroutine.resume, thread)
					end
				end)

				yielded = true
				coroutine.yield()
				return a, b
			end,

			Fire = function(self: IAS.IAScriptSignal, active: boolean, pressed: boolean)
				local node = head
				while node do
					local nxt = node.next
					if node.connected then
						if node.parallel then
							dispatchParallel(node.fn, active, pressed)
						else
							pcall(node.fn, active, pressed)
						end
					end
					node = nxt
				end
			end

		}

		return Signal
	end
}
