-- closure scoping reimplement of https://github.com/LPGhatguy/lemur/blob/master/lib/Signal.lua
local Signal = {}

local function listInsert(list, ...)
	local args = {...}
	local newList = {}
	local listLen = #list
		
	for i = 1, listLen do
		newList[i] = list[i]
	end
		
	for i = 1, #args do
		newList[listLen + i] = args[i]
	end
		
	return newList
end
	
local function listValueRemove(list, value)
	local newList = {}

	for i = 1, #list do
		if list[i] ~= value then
			table.insert(newList, list[i])
		end
	end
		
	return newList
end

function Signal.new()
	local signal = {}
	
	local boundCallbacks = {}
	local singleCallbacks = {}
    local connections = {}
	local singleConnections = {}
	
	function signal:Connect(cb)

		boundCallbacks = listInsert(boundCallbacks, cb)

        local newConnection = {Disconnect = nil, Connected = true}

		local function disconnect()
			boundCallbacks = listValueRemove(boundCallbacks, cb)
            newConnection.Connected = false
		end

        newConnection.Disconnect = disconnect

        connections = listInsert(connections, newConnection)

		return newConnection
	end

	function signal:Once(cb)

		singleCallbacks = listInsert(singleCallbacks, cb)

		local newConnection = {Disconnect = nil, Connected = true}

		local function disconnect()
			singleCallbacks = listValueRemove(singleCallbacks, cb)
			newConnection.Connected = false
		end

		newConnection.Disconnect = disconnect

		singleConnections = listInsert(singleConnections, newConnection)

		return newConnection
	end
	
	function signal:Fire(...)
		
		for i = 1, #boundCallbacks do
			boundCallbacks[i](...)
		end

		for i = 1, #singleCallbacks do
			singleCallbacks[i](...)
		end

		for _, connection in singleConnections do
			connection:Disconnect()
			connection = nil
		end

	end

    function signal:Destroy()
        for _, connection in connections do
            connection:Disconnect()
        end

		for _, connection in singleConnections do
			connection:Disconnect()
		end
    end
	
	return signal
end

return Signal