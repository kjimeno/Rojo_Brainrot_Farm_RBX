-- EnergyConversionSystem.luau
-- Lives at ServerScriptService.Server.EnergyConversionSystem
-- Handles: collecting energy off the conveyor, depositing it, converting it to cash over time,
-- and collecting the converted cash. Also drives the SurfaceGui "board".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local AFFORD_COLOR = Color3.fromRGB(85, 255, 127)
local CANT_AFFORD_COLOR = Color3.fromRGB(255, 60, 60)
local CASH_COLOR = Color3.fromRGB(60, 200, 100)

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
		"Silo: %d\nPending Cash: %d\nRate: %.1f/s",
		data.SiloEnergy, data.PendingCash, rate
	)

	local vault = plot:FindFirstChild("CoinVault")
	local cashBillboard = vault and vault:FindFirstChild("CashVaultBillboard")
	local amountLabel = cashBillboard and cashBillboard:FindFirstChild("AmountLabel")
	if amountLabel then
		amountLabel.Text = tostring(data.PendingCash)
	end

	local upgradePlatform = plot:FindFirstChild("UpgradePlatform")
	if upgradePlatform then
		local upgradeBillboard = upgradePlatform:FindFirstChild("UpgradeBillboard")
		local rateLabel = upgradeBillboard and upgradeBillboard:FindFirstChild("RateLabel")
		local costLabel = upgradeBillboard and upgradeBillboard:FindFirstChild("CostLabel")

		if data.ConversionLevel >= GameConfig.ConversionUpgrade.MaxLevel then
			if rateLabel then rateLabel.Text = "MAX" end
			if costLabel then costLabel.Text = "LEVEL" end
			upgradePlatform.Color = Color3.new(1, 1, 1)
		else
			-- Both the rate increase AND the cost grow with each purchase (RateGrowth / CostGrowth
			-- respectively), so both lines have to be recomputed from the player's current level
			-- every time, not baked in once when the billboard was first created.
			if rateLabel then
				rateLabel.Text = ("+%.2f/s"):format(GameConfig.GetNextRateIncrease(data.ConversionLevel))
			end
			local cost = GameConfig.GetUpgradeCost(data.ConversionLevel)
			if costLabel then costLabel.Text = ("%d cash"):format(cost) end
			upgradePlatform.Color = (data.Cash >= cost) and AFFORD_COLOR or CANT_AFFORD_COLOR
		end
	end
end

-- Creates the floating "Collect Cash" / amount text above the CoinVault platform, if it
-- doesn't already exist (safe to call every server start without duplicating it).
local function ensureCoinVaultBillboard(vault: Instance)
	if vault:FindFirstChild("CashVaultBillboard") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CashVaultBillboard"
	billboard.Adornee = vault
	billboard.Size = UDim2.new(0, 200, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = vault

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = "Collect Cash"
	titleLabel.Parent = billboard

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "AmountLabel"
	amountLabel.Size = UDim2.new(1, 0, 0.5, 0)
	amountLabel.Position = UDim2.new(0, 0, 0.5, 0)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Font = Enum.Font.GothamBold
	amountLabel.TextScaled = true
	amountLabel.TextColor3 = Color3.new(1, 1, 1)
	amountLabel.Text = "0"
	amountLabel.Parent = billboard
end

-- Creates the floating "+rate/s" / cost text above the UpgradePlatform, if it doesn't already
-- exist (safe to call every server start without duplicating it). Both lines start out showing
-- the level-0 values as a placeholder; updateBoard refreshes both every time, since both the
-- rate increase and the cost grow with the plot owner's current ConversionLevel.
local function ensureUpgradeBillboard(platform: Instance)
	if platform:FindFirstChild("UpgradeBillboard") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "UpgradeBillboard"
	billboard.Adornee = platform
	billboard.Size = UDim2.new(0, 200, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = platform

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Size = UDim2.new(1, 0, 0.5, 0)
	rateLabel.Position = UDim2.new(0, 0, 0, 0)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Font = Enum.Font.GothamBold
	rateLabel.TextScaled = true
	rateLabel.TextColor3 = Color3.new(1, 1, 1)
	rateLabel.Text = ("+%.2f/s"):format(GameConfig.ConversionUpgrade.RatePerLevel)
	rateLabel.Parent = billboard

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.Size = UDim2.new(1, 0, 0.5, 0)
	costLabel.Position = UDim2.new(0, 0, 0.5, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextScaled = true
	costLabel.TextColor3 = CASH_COLOR
	costLabel.Text = ("%d cash"):format(GameConfig.GetUpgradeCost(0))
	costLabel.Parent = billboard
end

-- Shared by both the RemoteEvent (for future UI) and the UpgradePlatform's Touched handler.
local function tryUpgradeConversion(player: Player): (boolean, number | string)
	local data = PlayerDataManager.Get(player)
	if not data then return false, "Data not loaded" end

	if data.ConversionLevel >= GameConfig.ConversionUpgrade.MaxLevel then
		return false, "Max level reached"
	end

	local cost = GameConfig.GetUpgradeCost(data.ConversionLevel)
	if data.Cash < cost then
		return false, "Not enough cash"
	end

	data.Cash -= cost
	data.ConversionLevel += 1
	return true, data.ConversionLevel
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

		-- No cap -- move all carried energy into the silo in one go.
		data.SiloEnergy += data.StoredEnergy
		data.StoredEnergy = 0

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

-- ===== 3. Converting silo energy -> pending cash over time (1 energy = 1 cash) =====
local function startConversionLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerDataManager.Get(player)
				if data and data.SiloEnergy > 0 then
					-- GetConversionRate can be fractional (RateGrowth compounds per upgrade), so
					-- floor to a whole number here -- otherwise SiloEnergy/PendingCash would pick
					-- up fractional remainders and the cash to collect would show decimals.
					local rate = GameConfig.GetConversionRate(data.ConversionLevel)
					local converted = math.floor(math.min(rate, data.SiloEnergy))

					if converted > 0 then
						data.SiloEnergy -= converted
						data.PendingCash += converted

						local plot = getPlayerPlot(player)
						if plot then
							updateBoard(plot, data)
						end
					end
				end
			end
		end
	end)
end

-- ===== 4. Collecting pending cash from the vault =====
local function setupCoinVault(plot: Instance)
	local vault = plot:FindFirstChild("CoinVault")
	if not vault then return end

	ensureCoinVaultBillboard(vault)

	local onCooldown = {}

	vault.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or onCooldown[player] then return end

		local data = PlayerDataManager.Get(player)
		if not data or data.PendingCash <= 0 then return end

		onCooldown[player] = true
		data.Cash += data.PendingCash
		data.PendingCash = 0

		Remotes.StatsUpdate:FireClient(player, { Cash = data.Cash, PendingCash = 0 })
		updateBoard(plot, data)

		task.delay(1, function()
			onCooldown[player] = nil
		end)
	end)
end

-- ===== 5. Buying a conversion speed upgrade =====
Remotes.UpgradeConversion.OnServerEvent:Connect(function(player)
	local success, resultOrError = tryUpgradeConversion(player)
	Remotes.UpgradeConversion:FireClient(player, success, resultOrError)

	if success then
		local plot = getPlayerPlot(player)
		if plot then
			updateBoard(plot, PlayerDataManager.Get(player))
		end
	end
end)

-- Step on the UpgradePlatform to buy the same conversion-speed upgrade, no UI needed.
local function setupUpgradePlatform(plot: Instance)
	local platform = plot:FindFirstChild("UpgradePlatform")
	if not platform then return end

	ensureUpgradeBillboard(platform)

	local onCooldown = {}

	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or onCooldown[player] then return end

		onCooldown[player] = true

		local success, resultOrError = tryUpgradeConversion(player)
		if success then
			local data = PlayerDataManager.Get(player)
			Remotes.StatsUpdate:FireClient(player, { Cash = data.Cash })
			updateBoard(plot, data)
			print(("[Upgrade] %s bought conversion level %s"):format(player.Name, tostring(resultOrError)))
		else
			print(("[Upgrade] %s failed to buy conversion upgrade: %s"):format(player.Name, tostring(resultOrError)))
		end

		task.delay(1, function()
			onCooldown[player] = nil
		end)
	end)
end

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
		setupUpgradePlatform(plot)
	end
end

initAllPlots()
startConversionLoop()

return {
	GetPlayerPlot = getPlayerPlot,
	UpdateBoard = updateBoard,
}
