--!strict
--[[
    SecurePrompt.lua
    Author: Michael S (DevIrradiant)

    Description: Designed to secure prompts server-side, especially handy for longer hold duration prompts. A prompt can have its HoldDuration
    updated from the client, and will still fire the Triggered event after the client's modified HoldDuration. This will intake a prompt, and 
    reference its HoldDuration to compare the initial trigger time against the Triggered event timestamp. Unfortunately, the current events 
    for ProximityPrompts fire in the order of:

    - PromptButtonHoldBegan
    - PromptButtonHoldEnded
    - PromptTriggered
    - TriggerEnded

    Stored timestamps become more difficult to clean up due to PromptButtonHoldended firing before PromptTriggered, as this event would normally
    be used for the cleanup but will instead leave you with no entry to compare against in the PromptTriggered connection.

    Instead, each PromptButtonHoldBegan event will cache the entry locally, and attempt cleanup 1 second after the expected HoldDuration if the 
    existing entry matches the cached entry.
]]

-- Constants
local HOLD_DURATION_BUFFER = 0.1

-- Modules
local Signal = require(script.Signal)

-- Types
type Interface = {
-- Internal
    __index: Interface,

-- External
    Secure: (prompt: ProximityPrompt) -> SecuredPrompt,
    Destroy: (SecuredPrompt) -> nil
}
type Props = {
-- Internal
    _connections: {RBXScriptConnection},
    _activePlayers: {[Player]: number},
-- External
    Triggered: RBXScriptSignal
}

export type SecuredPrompt = typeof(setmetatable({} :: Props, {} :: Interface))?

--[=[
    @prop Triggered RBXScriptSignal
    @within SecuredPrompt
]=]



--[=[
    @class SecuredPrompt

    An object that ensures the Triggered event fired after the set HoldDuration based on initial input.
]=]
local SecuredPrompt = {} :: Interface
SecuredPrompt.__index = SecuredPrompt

--[=[
    Constructs new SecuredPrompt, establishes event connections and new Triggered event.

    @within SecuredPrompt
    @param prompt ProximityPrompt -- ProximityPrompt to be secured.
    @return self SecuredPrompt -- Constructed SecuredPrompt
]=]
function SecuredPrompt.Secure(prompt: ProximityPrompt)
    local self = setmetatable({}, SecuredPrompt)

    -- Internal Refs
    self._connections = {}
    self._activePlayers = {}

    -- External Refs
    self.Triggered = Signal.new()

    -- Generate entries for when input began per Player.
    table.insert(self._connections, prompt.PromptButtonHoldBegan:Connect(function(player: Player)
        local timestamp = workspace:GetServerTimeNow()
        self._activePlayers[player] = timestamp

        -- Automatically cleanup this entry after the HoldDuration if the player hasn't Triggered the prompt, or began new input.
        task.delay(prompt.HoldDuration + 1, function()
            -- Exit if Player has already been removed.
            if self._activePlayers[player] == nil then
                return
            end

            -- Exit if Player has triggered this prompt again.
            if self._activePlayers[player] ~= timestamp then
                return
            end

            -- Remove the entry
            self._activePlayers[player] = nil
        end)
    end))

    -- Fire the supplied callback if the HoldDuration was met.
    table.insert(self._connections, prompt.Triggered:Connect(function(player: Player)
        -- Exit if Player entry is missing.
        if self._activePlayers[player] == nil then
            return
        end

        -- Exit if Player's initial input timestamp doesn't meet the HoldDuration.
        local timestamp = workspace:GetServerTimeNow()
        local timestampComparative = self._activePlayers[player]
        local duration = timestamp - timestampComparative

        if duration + HOLD_DURATION_BUFFER < prompt.HoldDuration then
            return
        end

        -- Fire Triggered event
        self.Triggered:Fire(player)
    end))

    return self
end

--[=[
    Cleans up the constructed SecuredPrompt connections.

    @within SecuredPrompt
]=]
function SecuredPrompt:Destroy()
    if not self then
        return
    end

    -- Clean up connections
    for _, connection in self._connections do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
    self._connections = {}

    self = nil

    return
end

return SecuredPrompt
