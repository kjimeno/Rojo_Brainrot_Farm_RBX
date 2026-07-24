-- EnergyConversionSystem.luau
-- Lives at ServerScriptService.Server.EnergyConversionSystem
-- Handles: collecting energy off the conveyor, depositing it, converting it to coins over time,
-- and collecting the converted coins. Also drives the SurfaceGui "board".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

-- ===== 1. Energy collection =====
-- Handled in BrainrotSpawner.luau via Tween.Completed instead of a Touched listener here —
-- Touched never fires between two Anchored parts, and both the energy part and the Collector
-- part are Anchored, so a Touched-based approach on this part would silently never trigger.
-- Kept the Collector part itself in your plot for visual/positional reference only.

local function getPlayerPlot(player: Player)
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- Refreshes the physical SurfaceGui board on the player's plot (built manually in Studio as
-- <plot>/ConversionBoard/Board/SurfaceGui/Label) to reflect their current silo/coin numbers.
-- Searches recursively for the SurfaceGui/Label since they live on a child part ("Board")
-- inside the ConversionBoard model, not on the model itself.
local function updateBoard(plot: Instance, data)
	local board = plot:FindFirstChild("ConversionBoard", true)
	if not board then
		warn("[EnergyConversionSystem] No ConversionBoard found under " .. plot.Name)
		return
	end

	local surfaceGui = board:FindFirstChildWhichIsA("SurfaceGui", true)
	if not surfaceGui then
		warn("[EnergyConversionSystem] ConversionBoard under " .. plot.Name .. " has no SurfaceGui descendant")
		return
	end

	local label = surfaceGui:FindFirstChild("Label", true) or surfaceGui:FindFirstChildWhichIsA("TextLabel", true)
	if not label then
		warn("[EnergyConversionSystem] SurfaceGui on " .. plot.Name .. "'s ConversionBoard has no Label/TextLabel")
		return
	end

	local rate = GameConfig.GetConversionRate(data.ConversionLevel)
	label.Text = string.format(
		"Silo: %d\nPending Coins: %d\nRate: %.1f/s",
		data.SiloEnergy, data.PendingCoins, rate
	)
end

-- ===== 2. Depositing carried energy into the silo =====
local function setupDepositArea(plot: Instance)
	local depositPart = plot:FindFirstChild("DepositArea")
	if not depositPart then return end

	local playersInside = {}

	depositPart.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or playersInside[player] then return end

		local data = PlayerDataManager.Get(player)
		if not data or data.StoredEnergy <= 0 then return end

		playersInside[player] = true

		local spaceLeft = GameConfig.MaxSiloCapacity - data.SiloEnergy
		local toDeposit = math.min(data.StoredEnergy, math.max(spaceLeft, 0))

		data.SiloEnergy += toDeposit
		data.StoredEnergy -= toDeposit

		Remotes.StatsUpdate:FireClient(player, {
			StoredEnergy = data.StoredEnergy,
			SiloEnergy = data.SiloEnergy,
		})
		updateBoard(plot, data)

		task.delay(1, function()
			playersInside[player] = nil
		end)
	end)
end

-- ===== 3. Converting silo energy -> pending coins over time (1 energy = 1 coin) =====
local function startConversionLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataManager.Get(player)
				if data and data.SiloEnergy > 0 then
					local rate = GameConfig.GetConversionRate(data.ConversionLevel)
					local converted = math.min(rate, data.SiloEnergy)

					data.SiloEnergy -= converted
					data.PendingCoins += converted

					local plot = getPlayerPlot(player)
					if plot then
						updateBoard(plot, data)
					end
				end
			end
		end
	end)
end

-- ===== 4. Collecting pending coins from the vault =====
local function setupCoinVault(plot: Instance)
	local vault = plot:FindFirstChild("CoinVault")
	if not vault then return end

	local onCooldown = {}

	vault.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or onCooldown[player] then return end

		local data = PlayerDataManager.Get(player)
		if not data or data.PendingCoins <= 0 then return end

		onCooldown[player] = true
		data.Coins += data.PendingCoins
		data.PendingCoins = 0

		Remotes.StatsUpdate:FireClient(player, { Coins = data.Coins, PendingCoins = 0 })
		updateBoard(plot, data)

		task.delay(1, function()
			onCooldown[player] = nil
		end)
	end)
end

-- ===== 5. Buying a conversion speed upgrade =====
Remotes.UpgradeConversion.OnServerEvent:Connect(function(player)
	local data = PlayerDataManager.Get(player)
	if not data then return end

	if data.ConversionLevel >= GameConfig.ConversionUpgrade.MaxLevel then
		Remotes.UpgradeConversion:FireClient(player, false, "Max level reached")
		return
	end

	local cost = GameConfig.GetUpgradeCost(data.ConversionLevel)
	if data.Coins < cost then
		Remotes.UpgradeConversion:FireClient(player, false, "Not enough coins")
		return
	end

	data.Coins -= cost
	data.ConversionLevel += 1
	Remotes.UpgradeConversion:FireClient(player, true, data.ConversionLevel)

	local plot = getPlayerPlot(player)
	if plot then
		updateBoard(plot, data)
	end
end)

-- ===== Init: wire up every plot in the workspace =====
local function initAllPlots()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then
		warn("[EnergyConversionSystem] No workspace.Plots folder found — build your plots in Studio first.")
		return
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		setupDepositArea(plot)
		setupCoinVault(plot)
	end
end

initAllPlots()
startConversionLoop()

return true
