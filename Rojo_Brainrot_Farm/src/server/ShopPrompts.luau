-- ShopPrompts.luau
-- Lives at ServerScriptService.Server.ShopPrompts
-- Listens for ANY ProximityPrompt in the game that has a "BrainrotName" attribute set,
-- and treats triggering it as "buy this brainrot for this player."
-- This lets you build a shop stall entirely with placeholder Parts + ProximityPrompts —
-- no client UI or RemoteEvent wiring needed to test the buy flow.
--
-- Each platform is one Part with a ProximityPrompt child carrying attributes:
--   BrainrotName = "Tralalero"   -- required
--   Quantity     = 5             -- optional, defaults to 1 (e.g. the 1x/5x/25x/100x tier-1 stalls)

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BrainrotSpawner = require(script.Parent.BrainrotSpawner)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local EnergyConversionSystem = require(script.Parent.EnergyConversionSystem)
local MergeSystem = require(script.Parent.MergeSystem)

-- Floating "Buy 5x Tralalero / 25 cash" text above a shop platform (the Part the
-- ProximityPrompt is parented to). Created once per prompt, safe to re-run on server start.
local function ensureShopBillboard(prompt: ProximityPrompt, brainrotName: string, quantity: number)
	local platform = prompt.Parent
	if not platform or not platform:IsA("BasePart") then return end
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

-- Build the floating text for every shop prompt that already exists in the workspace
-- (the platforms themselves are built manually in Studio, same as the plots/board).
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") then
		local brainrotName = descendant:GetAttribute("BrainrotName")
		if brainrotName then
			local quantity = descendant:GetAttribute("Quantity") or 1
			ensureShopBillboard(descendant, brainrotName, quantity)
		end
	end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local brainrotName = prompt:GetAttribute("BrainrotName")
	if not brainrotName then return end -- not a shop prompt, ignore it

	local quantity = prompt:GetAttribute("Quantity") or 1
	local success, resultOrError = BrainrotSpawner.BuyBrainrot(player, brainrotName, quantity)

	if success then
		local data = PlayerDataManager.Get(player)
		Remotes.StatsUpdate:FireClient(player, { Cash = data.Cash })

		-- Spending cash here can change whether the player can afford their next
		-- conversion upgrade, so refresh that sign's afford/can't-afford color too.
		local plot = EnergyConversionSystem.GetPlayerPlot(player)
		if plot then
			EnergyConversionSystem.UpdateBoard(plot, data)

			-- Buying can push a tier up to 3+ owned copies, so the merge platform might have
			-- just become ready -- refresh its yellow/grey state too.
			MergeSystem.UpdateMergePlatform(plot, data)
		end

		print(("[Shop] %s bought %dx %s. Cash left: %d"):format(player.Name, quantity, brainrotName, data.Cash))
	else
		print(("[Shop] %s failed to buy %dx %s: %s"):format(player.Name, quantity, brainrotName, tostring(resultOrError)))
		-- Once you build real UI, fire a dedicated remote here to show an error toast/sound.
	end
end)

return true
