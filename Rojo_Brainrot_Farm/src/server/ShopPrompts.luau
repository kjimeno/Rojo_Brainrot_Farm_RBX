-- ShopPrompts.luau
-- Lives at ServerScriptService.Server.ShopPrompts
-- Listens for Touched on ANY Part in the game that has a "BrainrotName" attribute set, and
-- treats stepping on it as "buy this brainrot for this player." This lets you build a shop
-- stall entirely with placeholder Parts -- no ProximityPrompt or client UI wiring needed.
--
-- Each platform is one Part carrying attributes directly on itself:
--   BrainrotName = "Noobini Pizzanini"   -- required
--   Quantity     = 5                     -- optional, defaults to 1 (e.g. the 1x/5x/25x/100x tier-1 stalls)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BrainrotSpawner = require(script.Parent.BrainrotSpawner)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local EnergyConversionSystem = require(script.Parent.EnergyConversionSystem)
local MergeSystem = require(script.Parent.MergeSystem)
local setupRepeatingTouch = require(script.Parent.RepeatingTouch)

-- Floating "Buy 5x Noobini Pizzanini / 25 cash" text above a shop platform. Created once per
-- platform, safe to re-run on server start.
local function ensureShopBillboard(platform: BasePart, brainrotName: string, quantity: number)
	if platform:FindFirstChild("ShopBillboard") then return end

	local config = GameConfig.Brainrots[brainrotName]
	if not config then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopBillboard"
	billboard.Adornee = platform
	billboard.Size = UDim2.new(0, 200, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = platform

	local quantityLabel = Instance.new("TextLabel")
	quantityLabel.Name = "QuantityLabel"
	quantityLabel.Size = UDim2.new(1, 0, 0.5, 0)
	quantityLabel.Position = UDim2.new(0, 0, 0, 0)
	quantityLabel.BackgroundTransparency = 1
	quantityLabel.Font = Enum.Font.GothamBold
	quantityLabel.TextScaled = true
	quantityLabel.TextColor3 = Color3.new(1, 1, 1)
	quantityLabel.Text = ("Buy %dx %s"):format(quantity, brainrotName)
	quantityLabel.Parent = billboard

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(1, 0, 0.5, 0)
	priceLabel.Position = UDim2.new(0, 0, 0.5, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextScaled = true
	priceLabel.TextColor3 = Color3.fromRGB(60, 200, 100)
	priceLabel.Text = ("%d cash"):format(config.Price * quantity)
	priceLabel.Parent = billboard
end

local function buyAt(platform: BasePart, player: Player, brainrotName: string, quantity: number)
	local success, resultOrError = BrainrotSpawner.BuyBrainrot(player, brainrotName, quantity)

	if success then
		local data = PlayerDataManager.Get(player)
		Remotes.StatsUpdate:FireClient(player, { Cash = data.Cash })

		-- Spending cash here can change whether the player can afford their next conversion
		-- upgrade, and buying can push a tier up to 3+ owned copies making a merge possible --
		-- refresh both of those signs too.
		local plot = EnergyConversionSystem.GetPlayerPlot(player)
		if plot then
			EnergyConversionSystem.UpdateBoard(plot, data)
			MergeSystem.UpdateMergePlatform(plot, data)
		end

		-- The 100x shop platforms buy so many at once that they're almost guaranteed to complete
		-- several merge groups immediately -- auto-merge everything possible right away instead
		-- of leaving the player to walk over to the merge platform themselves. (AutoMergeAll
		-- re-fetches/updates the board and plot itself, so this is safe even though the block
		-- above just did the same for the plain purchase case.)
		if quantity >= 100 then
			MergeSystem.AutoMergeAll(player)
		end

		print(("[Shop] %s bought %dx %s. Cash left: %d"):format(player.Name, quantity, brainrotName, data.Cash))
	else
		print(("[Shop] %s failed to buy %dx %s: %s"):format(player.Name, quantity, brainrotName, tostring(resultOrError)))
		-- Once you build real UI, fire a dedicated remote here to show an error toast/sound.
	end
end

local function setupShopPlatform(platform: BasePart)
	local brainrotName = platform:GetAttribute("BrainrotName")
	if not brainrotName then return end

	local quantity = platform:GetAttribute("Quantity") or 1
	ensureShopBillboard(platform, brainrotName, quantity)

	setupRepeatingTouch(platform, function(player)
		buyAt(platform, player, brainrotName, quantity)
	end)
end

-- Wire up every shop platform that already exists in the workspace (the platforms themselves
-- are built manually in Studio, same as the plots/board).
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") and descendant:GetAttribute("BrainrotName") then
		setupShopPlatform(descendant)
	end
end

return true
