-- init.server.luau
-- This becomes ServerScriptService.Server (a Script) since its name starts with "init.".
-- Its sibling ModuleScripts (PlayerDataManager, BrainrotSpawner, etc.) are its children,
-- so we require them as `script.<Name>`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlayerDataManager = require(script.PlayerDataManager)

-- The client script also sets ResetOnSpawn=false on the live PlayerGui.Main clone, but that
-- alone wasn't preventing the reset -- Roblox's respawn logic likely reads the STARTERGUI
-- TEMPLATE's own ResetOnSpawn (still true, its default, since only the runtime clone had been
-- touched) to decide whether to tear a player's copy down and reclone it, not the live clone's
-- current value. Setting it here, on the template itself, before any player can possibly join
-- or spawn a character.
local mainGui = StarterGui:FindFirstChild("Main")
if mainGui then
	mainGui.ResetOnSpawn = false
end

-- Requiring these modules runs their top-level code, which wires up all the
-- RemoteEvent listeners and Touched connections. Order matters: BrainrotSpawner
-- and EnergyConversionSystem don't depend on each other, but MergeSystem needs
-- BrainrotSpawner already loaded (it calls BrainrotSpawner.StartEnergyLoop), and
-- ShopPrompts needs both EnergyConversionSystem and MergeSystem already loaded.
local BrainrotSpawner = require(script.BrainrotSpawner)
local EnergyConversionSystem = require(script.EnergyConversionSystem)
local MergeSystem = require(script.MergeSystem)
local ShopPrompts = require(script.ShopPrompts)

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

-- Default Roblox WalkSpeed is 16 -- a bit faster for getting around the shop/plot quicker.
local WALK_SPEED = 20

-- MaxSlopeAngle defaults to 89 -- Roblox humanoids can auto climb almost any incline or ledge
-- edge (stand platforms, conveyor lips, etc.) without jumping. Dropping it low stops that
-- auto-climb while still leaving normal flat-ground walking untouched.
local MAX_SLOPE_ANGLE = 10

-- Re-applied on every CharacterAdded, since respawning gives the player a brand-new Humanoid
-- that resets to Roblox's defaults. Jump stays untouched -- only auto-climb is disabled.
--
-- HealthDisplayType defaults to DisplayWhenDamaged -- Roblox shows the floating health bar
-- above your head any time health is below max, INCLUDING at 0 (dead), which is the empty bar
-- you don't want showing. AlwaysOff removes that display entirely -- there's no combat/damage
-- mechanic in this game, so there's nothing worth showing a health bar for anyway.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = WALK_SPEED
		humanoid.MaxSlopeAngle = MAX_SLOPE_ANGLE
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end)

	PlayerDataManager.Load(player)

	local plot = assignPlot(player)
	if plot then
		local data = PlayerDataManager.Get(player)
		if data then
			-- Physically spawns everything in data.OwnedBrainrots onto the plot's grid --
			-- without this, a returning player's saved brainrots never appear until some other
			-- action (buying, merging) happens to trigger a repack as a side effect.
			BrainrotSpawner.RepackPlot(player, plot, data)
			EnergyConversionSystem.UpdateBoard(plot, data, player)
			MergeSystem.UpdateMergePlatform(plot, data)
		end
	end
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
		ShopTier = data.ShopTier,
		TotalBrainrotValue = GameConfig.GetTotalBrainrotValue(data.OwnedBrainrots),
	})

	local plot = EnergyConversionSystem.GetPlayerPlot(player)
	if plot then
		EnergyConversionSystem.UpdateBoard(plot, data, player)
		MergeSystem.UpdateMergePlatform(plot, data)
	end
	ShopPrompts.RefreshShopTierUpgradeDisplay(player)
	ShopPrompts.RefreshFollowingShopStalls(player)
end)

print("[Server] Brainrot Tycoon systems initialized.")
