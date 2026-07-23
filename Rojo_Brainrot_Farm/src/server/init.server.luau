-- init.server.luau
-- This becomes ServerScriptService.Server (a Script) since its name starts with "init.".
-- Its sibling ModuleScripts (PlayerDataManager, BrainrotSpawner, etc.) are its children,
-- so we require them as `script.<Name>`.

local Players = game:GetService("Players")

local PlayerDataManager = require(script.PlayerDataManager)

-- Load data as soon as a player joins, save + release when they leave.
Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.Load(player)

	-- TODO: assign the player to a free plot here, e.g.:
	-- local plot = PlotManager.AssignPlot(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.Release(player)

	-- TODO: free the player's plot here for reuse
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerDataManager.Save(player)
	end
end)

PlayerDataManager.StartAutosave(60)

-- Requiring these modules runs their top-level code, which wires up all the
-- RemoteEvent listeners and Touched connections. Order matters: BrainrotSpawner
-- and EnergyConversionSystem don't depend on each other, but MergeSystem needs
-- BrainrotSpawner already loaded (it calls BrainrotSpawner.StartEnergyLoop).
require(script.BrainrotSpawner)
require(script.EnergyConversionSystem)
require(script.MergeSystem)

print("[Server] Brainrot Tycoon systems initialized.")
