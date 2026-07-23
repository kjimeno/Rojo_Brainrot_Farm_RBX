-- EnergyConversionSystem.luau
-- Lives at ServerScriptService.Server.EnergyConversionSystem
-- Handles: collecting energy off the conveyor, depositing it, converting it to coins over time,
-- and collecting the converted coins. Also drives the SurfaceGui "board".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

-- ===== 1. Collecting energy at the end of the conveyor =====
local function setupCollector(plot: Instance)
	local collector = plot:FindFirstChild("Collector")
	if not collector then return end

	collector.Touched:Connect(function(hit)
		local ownerUserId = hit:GetAttribute("OwnerUserId")
		if not ownerUserId then return end

		local energyValue = hit:GetAttribute("EnergyValue")
		if not energyValue then return end

		local player = Players:GetPlayerByUserId(ownerUserId)
		if not player then return end

		local data = PlayerDataManager.Get(player)
		if not data then return end

		data.StoredEnergy += energyValue
		hit:Destroy()

		Remotes.StatsUpdate:FireClient(player, {
			StoredEnergy = data.StoredEnergy,
			Coins = data.Coins,
		})
	end)
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

		task.delay(1, function()
			playersInside[player] = nil
		end)
	end)
end

-- ===== 3. Converting silo energy -> pending coins over time =====
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

					local plot = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild(tostring(player.UserId))
					if plot then
						local board = plot:FindFirstChild("ConversionBoard", true)
						if board and board:FindFirstChild("SurfaceGui") then
							local label = board.SurfaceGui:FindFirstChild("Label")
							if label then
								label.Text = string.format(
									"Silo: %d\nPending Coins: %d\nRate: %.1f/s",
									data.SiloEnergy, data.PendingCoins, rate
								)
							end
						end
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
end)

-- ===== Init: wire up every plot in the workspace =====
local function initAllPlots()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then
		warn("[EnergyConversionSystem] No workspace.Plots folder found — build your plots in Studio first.")
		return
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		setupCollector(plot)
		setupDepositArea(plot)
		setupCoinVault(plot)
	end
end

initAllPlots()
startConversionLoop()

return true
