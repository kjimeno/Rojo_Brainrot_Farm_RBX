-- ShopPrompts.luau
-- Lives at ServerScriptService.Server.ShopPrompts
-- Listens for Touched on ANY Part in the game that has a "BrainrotName" or "FollowsShopTier"
-- attribute set, and treats stepping on it as "buy this brainrot for this player." This lets you
-- build a shop stall entirely with placeholder Parts -- no ProximityPrompt or client UI wiring
-- needed.
--
-- Each shop platform is one Part carrying attributes directly on itself, one of:
--   BrainrotName = "Noobini Pizzanini"   -- fixed: always sells this exact brainrot
--   FollowsShopTier = true               -- dynamic: sells GameConfig.BrainrotOrder[data.ShopTier]
--                                           for whichever player is currently buying -- what the
--                                           x1/x5/x25/x100 stalls should use, so unlocking a new
--                                           tier at the ShopTierUpgradePlatform below immediately
--                                           changes what they sell without rebuilding them
--   Quantity     = 5                     -- optional on either kind, defaults to 1
--
-- Separately, ShopTierUpgrade = true on a Part makes it the (single, global) platform that raises
-- a player's data.ShopTier by one -- see setupShopTierUpgradePlatform below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BrainrotSpawner = require(script.Parent.BrainrotSpawner)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local EnergyConversionSystem = require(script.Parent.EnergyConversionSystem)
local MergeSystem = require(script.Parent.MergeSystem)
local RepeatingTouch = require(script.Parent.RepeatingTouch)
local PlayerDataSignals = require(script.Parent.PlayerDataSignals)

-- Same colors EnergyConversionSystem's UpgradePlatform uses for its own afford/can't-afford
-- indicator, so this platform matches the rest of the game's visual language.
local AFFORD_COLOR = Color3.fromRGB(73, 201, 105)
local CANT_AFFORD_COLOR = Color3.fromRGB(255, 99, 47)

-- Floating "Buy 5x Noobini Pizzanini / 25 cash" text above a shop platform. Created once per
-- platform, safe to re-run on server start -- starts showing whatever brainrotName/quantity it
-- was first set up with; updateShopBillboardText below keeps it current afterward.
local function ensureShopBillboard(platform: BasePart, brainrotName: string, quantity: number)
	if platform:FindFirstChild("ShopBillboard") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopBillboard"
	billboard.Adornee = platform
	billboard.Size = UDim2.new(0, 200, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = platform

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Parent = billboard

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(1, 0, 0.5, 0)
	priceLabel.Position = UDim2.new(0, 0, 0.5, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextScaled = true
	priceLabel.TextColor3 = Color3.fromRGB(60, 200, 100)
	priceLabel.Parent = billboard

	local function updateNow()
		local config = GameConfig.Brainrots[brainrotName]
		if not config then return end
		nameLabel.Text = ("Buy %dx %s"):format(quantity, brainrotName)
		priceLabel.Text = ("%s cash"):format(GameConfig.FormatAbbreviatedNumber(config.Price * quantity))
	end
	updateNow()
end

-- Updates an already-created ShopBillboard's text AND the platform's own color in place -- used
-- by FollowsShopTier platforms, where brainrotName/price (and now affordability) depends on
-- whichever player is being shown rather than being fixed at setup time. NameLabel/PriceLabel are
-- direct children of the billboard (not a deep search), so this is cheap to call on every trigger.
local function updateShopBillboardText(platform: BasePart, brainrotName: string, quantity: number, cash: number)
	local billboard = platform:FindFirstChild("ShopBillboard")
	if not billboard then return end
	local config = GameConfig.Brainrots[brainrotName]
	if not config then return end

	local totalPrice = config.Price * quantity
	local nameLabel = billboard:FindFirstChild("NameLabel")
	if nameLabel then
		nameLabel.Text = ("Buy %dx %s"):format(quantity, brainrotName)
	end
	local priceLabel = billboard:FindFirstChild("PriceLabel")
	if priceLabel then
		priceLabel.Text = ("%s cash"):format(GameConfig.FormatAbbreviatedNumber(totalPrice))
	end
	platform.Color = (cash >= totalPrice) and AFFORD_COLOR or CANT_AFFORD_COLOR
end

local function buyAt(platform: BasePart, player: Player, brainrotName: string, quantity: number)
	-- Bulk buys (100+) are always immediately followed by AutoMergeAll below, which calls
	-- RepackPlot and wipes/rebuilds the whole plot from data regardless -- so physically
	-- spawning e.g. 100 individual models (each with its own StandPlatform, nameplate, and a
	-- persistent energy-loop coroutine) just to have them destroyed moments later is pure
	-- wasted work, repeated on every RepeatingTouch trigger. skipPhysicalSpawn skips straight to
	-- updating the data and lets RepackPlot do the only spawning that actually ends up visible.
	-- Only safe when a merge is actually guaranteed to happen afterward though (MergeRequirement
	-- copies definitely exist at 100+), so max-tier brainrots (no MergeInto, can never merge)
	-- still spawn normally -- otherwise a bulk buy of those would never visibly appear at all.
	local config = GameConfig.Brainrots[brainrotName]
	local skipPhysicalSpawn = quantity >= 100 and config ~= nil and config.MergeInto ~= nil

	local success, resultOrError = BrainrotSpawner.BuyBrainrot(player, brainrotName, quantity, skipPhysicalSpawn)

	if success then
		local data = PlayerDataManager.Get(player)
		Remotes.StatsUpdate:FireClient(player, { Cash = data.Cash })
		PlayerDataSignals.FireCashChanged(player)

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
		-- above just did the same for the plain purchase case.) This is also what actually spawns
		-- anything visible when skipPhysicalSpawn was used above, via its own RepackPlot call.
		if quantity >= 100 then
			MergeSystem.AutoMergeAll(player)
		end

		print(("[Shop] %s bought %dx %s. Cash left: %d"):format(player.Name, quantity, brainrotName, data.Cash))
	else
		print(("[Shop] %s failed to buy %dx %s: %s"):format(player.Name, quantity, brainrotName, tostring(resultOrError)))

		-- Both of these mean "the purchase itself would be fine, but there's nowhere to put the
		-- result" -- worth a HUD callout since RepeatingTouch means the player will otherwise
		-- just keep silently failing every second while standing there wondering why.
		if resultOrError == "No free slot on plot" or resultOrError == "Not enough room on plot" then
			Remotes.ShopSpaceError:FireClient(player)
		elseif resultOrError == "Not enough cash" then
			Remotes.MoneyError:FireClient(player)
		end
	end
end

-- Every platform set up with FollowsShopTier=true, so refreshFollowingShopStalls below can
-- update ALL of them (x1/x5/x25/x100 alike) the moment any player's ShopTier changes, instead
-- of each one only correcting itself the next time someone happens to touch it.
local followsShopTierPlatforms: { { platform: BasePart, quantity: number } } = {}

local function setupShopPlatform(platform: BasePart)
	local quantity = platform:GetAttribute("Quantity") or 1

	if platform:GetAttribute("FollowsShopTier") then
		-- Billboard starts showing tier 1 as a placeholder; the first actual touch immediately
		-- corrects it to whichever tier that player has unlocked.
		ensureShopBillboard(platform, GameConfig.BrainrotOrder[1], quantity)
		table.insert(followsShopTierPlatforms, { platform = platform, quantity = quantity })

		RepeatingTouch.Setup(platform, function(player)
			local data = PlayerDataManager.Get(player)
			local shopTier = (data and data.ShopTier) or 1
			local brainrotName = GameConfig.BrainrotOrder[shopTier] or GameConfig.BrainrotOrder[1]
			updateShopBillboardText(platform, brainrotName, quantity, (data and data.Cash) or 0)
			buyAt(platform, player, brainrotName, quantity)
		end)
		return
	end

	local brainrotName = platform:GetAttribute("BrainrotName")
	if not brainrotName then return end

	ensureShopBillboard(platform, brainrotName, quantity)

	-- No custom schedule passed -- every shop platform (1x/5x/25x/100x alike) uses
	-- RepeatingTouch's own default: first two triggers at the normal pace, then fast.
	RepeatingTouch.Setup(platform, function(player)
		buyAt(platform, player, brainrotName, quantity)
	end)
end

-- ===== Shop tier upgrade platform: pay to unlock the next brainrot tier at the shop =====
-- A single platform (built once in Studio, tagged with the ShopTierUpgrade attribute, found the
-- same way as the shop stalls themselves rather than as a per-plot fixture -- which tier you can
-- buy at the shop is account-wide progress, not tied to any one plot) that raises a player's
-- data.ShopTier by one every time they touch it with enough cash. Every FollowsShopTier stall
-- reads that same value, so this is the only thing that ever changes what those stalls sell.
-- Reuses the exact same ShopBillboard/NameLabel/PriceLabel shape as the regular shop stalls
-- (see ensureShopBillboard above) -- if you build this platform by copy-pasting an existing
-- shop stall, its billboard already has both labels and nothing new gets created here at all.
local function ensureShopTierBillboard(platform: BasePart)
	if platform:FindFirstChild("ShopBillboard") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ShopBillboard"
	billboard.Adornee = platform
	billboard.Size = UDim2.new(0, 220, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = platform

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Text = "Tier 1 -> Tier 2"
	nameLabel.Parent = billboard

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(1, 0, 0.5, 0)
	priceLabel.Position = UDim2.new(0, 0, 0.5, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextScaled = true
	priceLabel.TextColor3 = Color3.fromRGB(60, 200, 100)
	priceLabel.Text = ("$%s"):format(GameConfig.FormatAbbreviatedNumber(GameConfig.GetShopTierUpgradeCost(1)))
	priceLabel.Parent = billboard
end

-- Same per-toucher personalization as updateShopBillboardText above -- what the NEXT unlock
-- costs (and whether that player can currently afford it) depends on whoever's being shown.
-- Also colors the platform itself green/orange, same afford/can't-afford signal as
-- EnergyConversionSystem's UpgradePlatform, instead of leaving it a single static color.
local function updateShopTierBillboard(platform: BasePart, data)
	local billboard = platform:FindFirstChild("ShopBillboard")
	if not billboard then return end
	local nameLabel = billboard:FindFirstChild("NameLabel")
	local priceLabel = billboard:FindFirstChild("PriceLabel")

	local shopTier = data.ShopTier
	local maxTier = #GameConfig.BrainrotOrder
	if shopTier >= maxTier then
		if nameLabel then nameLabel.Text = "Max Tier Reached" end
		if priceLabel then priceLabel.Text = "" end
		platform.Color = AFFORD_COLOR
		return
	end

	local cost = GameConfig.GetShopTierUpgradeCost(shopTier)
	if nameLabel then nameLabel.Text = ("Tier %d -> Tier %d"):format(shopTier, shopTier + 1) end
	if priceLabel then priceLabel.Text = ("$%s"):format(GameConfig.FormatAbbreviatedNumber(cost)) end
	platform.Color = (data.Cash >= cost) and AFFORD_COLOR or CANT_AFFORD_COLOR
end

local function tryUpgradeShopTier(player: Player): (boolean, number | string)
	local data = PlayerDataManager.Get(player)
	if not data then return false, "Data not loaded" end

	local maxTier = #GameConfig.BrainrotOrder
	if data.ShopTier >= maxTier then
		return false, "Already at max tier"
	end

	local cost = GameConfig.GetShopTierUpgradeCost(data.ShopTier)
	if data.Cash < cost then
		return false, "Not enough cash"
	end

	data.Cash -= cost
	data.ShopTier += 1
	return true, data.ShopTier
end

-- There's only ever one of these (a single global platform, not per-plot), so it's kept here
-- rather than threaded through every caller -- refreshShopTierUpgradeDisplay below (exported)
-- uses this to update it for a player as soon as their data is ready, not just on touch.
local shopTierUpgradePlatform: BasePart? = nil

local function setupShopTierUpgradePlatform(platform: BasePart)
	shopTierUpgradePlatform = platform
	ensureShopTierBillboard(platform)

	RepeatingTouch.Setup(platform, function(player)
		local success, resultOrError = tryUpgradeShopTier(player)
		local data = PlayerDataManager.Get(player)
		if data then
			updateShopTierBillboard(platform, data)
		end

		if success then
			Remotes.StatsUpdate:FireClient(player, { Cash = data.Cash, ShopTier = data.ShopTier })
			PlayerDataSignals.FireCashChanged(player)
			PlayerDataSignals.FireShopTierChanged(player)
			print(("[Shop] %s unlocked shop tier %d"):format(player.Name, resultOrError :: number))
		else
			print(("[Shop] %s failed to unlock next shop tier: %s"):format(player.Name, tostring(resultOrError)))
			if resultOrError == "Not enough cash" then
				Remotes.MoneyError:FireClient(player)
			end
		end
	end)
end

-- Called from init.server.luau once a player's data has actually loaded (the RequestStats
-- handler -- same trigger that already fixes every OTHER sign/HUD value showing 0/stale until
-- some action happens to touch it) so the platform reflects real data immediately instead of
-- sitting on its Tier-1 placeholder text/color until someone happens to step on it first.
local function refreshShopTierUpgradeDisplay(player: Player)
	if not shopTierUpgradePlatform then return end
	local data = PlayerDataManager.Get(player)
	if not data then return end
	updateShopTierBillboard(shopTierUpgradePlatform, data)
end

-- Updates every FollowsShopTier stall's billboard (name/price/afford-color) to whatever `player`
-- currently has unlocked and can afford -- called whenever their Cash OR ShopTier changes, so the
-- x1/x5/x25/x100 stalls stay correct immediately instead of waiting for the next time someone
-- happens to touch each one individually.
local function refreshFollowingShopStalls(player: Player)
	local data = PlayerDataManager.Get(player)
	if not data then return end

	local shopTier = data.ShopTier or 1
	local brainrotName = GameConfig.BrainrotOrder[shopTier] or GameConfig.BrainrotOrder[1]
	for _, entry in ipairs(followsShopTierPlatforms) do
		updateShopBillboardText(entry.platform, brainrotName, entry.quantity, data.Cash)
	end
end

-- Real-time reactions to changes that happened somewhere else entirely (buying at a shop stall,
-- collecting the coin vault, buying a conversion upgrade -- anything that touches Cash or
-- ShopTier) so these shared platforms stay correct without needing to be touched themselves.
PlayerDataSignals.OnCashChanged(refreshShopTierUpgradeDisplay)
PlayerDataSignals.OnCashChanged(refreshFollowingShopStalls)
PlayerDataSignals.OnShopTierChanged(refreshShopTierUpgradeDisplay)
PlayerDataSignals.OnShopTierChanged(refreshFollowingShopStalls)

-- Wire up every shop platform that already exists in the workspace (the platforms themselves
-- are built manually in Studio, same as the plots/board).
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("BasePart") then
		if descendant:GetAttribute("BrainrotName") or descendant:GetAttribute("FollowsShopTier") then
			setupShopPlatform(descendant)
		elseif descendant:GetAttribute("ShopTierUpgrade") then
			setupShopTierUpgradePlatform(descendant)
		end
	end
end

return {
	RefreshShopTierUpgradeDisplay = refreshShopTierUpgradeDisplay,
	RefreshFollowingShopStalls = refreshFollowingShopStalls,
}
