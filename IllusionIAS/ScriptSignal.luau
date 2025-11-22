--!strict
-- ScriptSignal.luau
--[[ 
//////////////////////////// 
// Signal Factory Module // 
////////////////////////// 
]]

local IAS = require("./TypeDefinition")

local function makeConnectionObject()
	local connection: IAS.IAScriptConnection = {
		Connected = true,
		Disconnect = function() end,
	}
	return connection
end

return {
	makeSignal = function(): IAS.IAScriptSignal
		local listeners: { { conn: IAS.IAScriptConnection, cb: IAS.func } } = {}
		local parallelListeners: { { conn: IAS.IAScriptConnection, cb: IAS.func } } = {}
		
		local function disconnect(map, entry)
			return function()
				if not entry.conn.Connected then return end
				entry.conn.Connected = false
				for i = #map, 1, -1 do
					if map[i] == entry then
						table.remove(map, i)
						break
					end
				end
			end
		end

		local function makeConnection(targetMap: { { conn: IAS.IAScriptConnection, cb: IAS.func } }, func: IAS.func)
			local entry = { conn = makeConnectionObject(), cb = func }
			entry.conn.Disconnect = disconnect(targetMap, entry)
			entry.conn.Connected = true

			table.insert(targetMap, entry)
			return entry.conn
		end

		local function DesyncCall(cb: IAS.func, active: boolean, pressed: boolean)
			task.spawn(function()
				pcall(cb, active, pressed)
			end)
		end

		local signal: IAS.IAScriptSignal = {
			Connect = function(self: IAS.IAScriptSignal, func: IAS.func): IAS.IAScriptConnection
				return makeConnection(listeners, func)
			end,

			ConnectParallel = function(self: IAS.IAScriptSignal, func: IAS.func): IAS.IAScriptConnection
				return makeConnection(parallelListeners, func)
			end,

			Once = function(self: IAS.IAScriptSignal, func: IAS.func): IAS.IAScriptConnection
				local connection: IAS.IAScriptConnection
				connection = makeConnection(listeners, function(active, pressed)
					if not connection.Connected then return end
					connection:Disconnect()
					task.spawn(func, active, pressed)
				end)

				return connection
			end,

			Fire = function(self: IAS.IAScriptSignal, active: boolean, pressed: boolean)
				local syncCopy = {}
				for i = 1, #listeners do syncCopy[i] = listeners[i] end

				local parallelCopy = {}
				for i = 1, #parallelListeners do parallelCopy[i] = parallelListeners[i] end

				for i = 1, #syncCopy do
					local entry = syncCopy[i]
					if entry and entry.conn.Connected then
						task.spawn(function()
							pcall(entry.cb, active, pressed)
						end)
					end
				end

				for i = 1, #parallelCopy do
					local entry = parallelCopy[i]
					if entry and entry.conn.Connected then DesyncCall(entry.cb, active, pressed) end
				end
			end,
			
			Wait = function(self: IAS.IAScriptSignal): (boolean, boolean)
				local thread = coroutine.running()
				local resultActive = false
				local resultPressed = false

				local connection: IAS.IAScriptConnection
				connection = makeConnection(listeners, function(active, pressed)
					if not connection.Connected then return end
					connection:Disconnect()

					resultActive = active
					resultPressed = pressed

					task.spawn(coroutine.resume, thread)
				end)

				coroutine.yield()
				return resultActive, resultPressed
			end,
		}

		return signal
	end
}
