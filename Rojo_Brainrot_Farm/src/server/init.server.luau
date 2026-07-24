-- init.server.luau
-- This becomes ServerScriptService.Server (a Script) since its name starts with "init.".
-- Its sibling ModuleScripts (PlayerDataManager, BrainrotSpawner, etc.) are its children,
-- so we require them as `script.<Name>`.

local Players = game:GetService("Players")

local PlayerDataManager = require(script.PlayerDataManager)

-- ===== Basic first-come-first-served plot assignment =====
-- Good enough for solo/small-group testing. Replace with persistent per-player plots later
-- if you want players to keep the same plot across sessions.
local function assignPlot(player: Player)
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then
		warn("[PlotAssign] No workspace.Plots folder found — run the Studio setup script first.")
		return nil
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == nil then
			plot:SetAttribute("OwnerUserId", player.UserId)
			return plot
		end
	end

	warn("[PlotAssign] No free plots available for " .. player.Name)
	return nil
end

local function releasePlot(player: Player)
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			plot:SetAttribute("OwnerUserId", nil)
		end
	end
end

-- Load data as soon as a player joins, save + release when they leave.
Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.Load(player)
	assignPlot(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.Release(player)
	releasePlot(player)
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
require(script.ShopPrompts)

print("[Server] Brainrot Tycoon systems initialized.")
