-- init.server.luau
-- This becomes ServerScriptService.Server (a Script) since its name starts with "init.".
-- Its sibling ModuleScripts (PlayerDataManager, BrainrotSpawner, etc.) are its children,
-- so we require them as `script.<Name>`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataManager = require(script.PlayerDataManager)

-- Requiring these modules runs their top-level code, which wires up all the
-- RemoteEvent listeners and Touched connections. Order matters: BrainrotSpawner
-- and EnergyConversionSystem don't depend on each other, but MergeSystem needs
-- BrainrotSpawner already loaded (it calls BrainrotSpawner.StartEnergyLoop), and
-- ShopPrompts needs both EnergyConversionSystem and MergeSystem already loaded.
require(script.BrainrotSpawner)
local EnergyConversionSystem = require(script.EnergyConversionSystem)
local MergeSystem = require(script.MergeSystem)
require(script.ShopPrompts)

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

-- The client fires this once its own LocalScript has started up and connected its
-- StatsUpdate listener, so we know the reply below won't get lost -- firing StatsUpdate
-- proactively right after PlayerDataManager.Load (instead of waiting to be asked) would risk
-- the client not being ready to receive it yet. This is what makes the HUD/physical signs
-- show your real loaded values (e.g. 100 starting cash) instead of sitting at 0/$0 until the
-- first buy/deposit/collect/upgrade action happens to push an update.
Remotes.RequestStats.OnServerEvent:Connect(function(player)
	local data = PlayerDataManager.Get(player)

	-- Data usually finishes loading well before the client gets around to asking, but in case
	-- this request beats PlayerDataManager.Load to the punch, wait briefly instead of bailing.
	local attempts = 0
	while not data and attempts < 50 do
		task.wait(0.1)
		data = PlayerDataManager.Get(player)
		attempts += 1
	end
	if not data then return end

	Remotes.StatsUpdate:FireClient(player, {
		StoredEnergy = data.StoredEnergy,
		SiloEnergy = data.SiloEnergy,
		Cash = data.Cash,
		PendingCash = data.PendingCash,
	})

	local plot = EnergyConversionSystem.GetPlayerPlot(player)
	if plot then
		EnergyConversionSystem.UpdateBoard(plot, data)
		MergeSystem.UpdateMergePlatform(plot, data)
	end
end)

print("[Server] Brainrot Tycoon systems initialized.")
