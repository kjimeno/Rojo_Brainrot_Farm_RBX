-- init.client.luau
-- This becomes StarterPlayer.StarterPlayerScripts.Client (a LocalScript).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- Placeholder: prints stats whenever the server pushes an update.
-- Replace this with real UI (ScreenGui) once you're ready to build the shop/merge/upgrade menus.
Remotes.StatsUpdate.OnClientEvent:Connect(function(stats)
	for key, value in pairs(stats) do
		print(("[Stats] %s = %s"):format(key, tostring(value)))
	end
end)

-- Example client-side call (wire this to a real button later):
-- Remotes.BuyBrainrot:FireServer("Tralalero")

print("[Client] Connected. Known brainrot tiers:")
for _, name in ipairs(GameConfig.BrainrotOrder) do
	print(" -", name, "(tier " .. GameConfig.Brainrots[name].Tier .. ")")
end
