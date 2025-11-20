--!strict
-- ScriptSignal.luau
local IAS = require("./TypeDefinition")

--[[ 
//////////////////////////// 
// Signal Factory Module // 
////////////////////////// 
]]

return {
	makeSignal = function(): IAS.IAScriptSignal
		local listeners: {[IAS.IAScriptConnection]: IAS.func} = {}
		local parallelListeners: {[IAS.IAScriptConnection]: IAS.func} = {}

		local function disconnect(self: IAS.IAScriptConnection)
			if not self.Connected then return end

			self.Connected = false
			listeners[self] = nil
			parallelListeners[self] = nil
		end

		local function makeConnection(targetMap: {[IAS.IAScriptConnection]: IAS.func}, func: IAS.func): IAS.IAScriptConnection

			local connection: IAS.IAScriptConnection = {
				Connected = true,
				Disconnect = disconnect,
			}

			targetMap[connection] = func
			return connection
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
				for conn, cb in listeners do
					if conn.Connected then
						task.spawn(cb, active, pressed)
					end
				end

				for conn, cb in parallelListeners do
					if conn.Connected then
						task.desynchronize()
						pcall(cb, active, pressed)
						task.synchronize()
					end
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
