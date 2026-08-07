-- GameConfig.luau
-- Lives at ReplicatedStorage.Shared.GameConfig (accessible from client AND server)
-- Single source of truth for balancing.

local GameConfig = {}

-- ============ BRAINROT TIERS ============
-- Price keeps the x5-per-tier pattern you set for tiers 1-5; EnergyPerDrop keeps roughly the
-- same ~2.5x-per-tier curve. Just the names changed here -- values are unchanged per tier.
--
-- FacingOffset (optional, degrees) corrects a model whose PrimaryPart doesn't actually face
-- the way the character visually looks -- common with imported models that weren't authored
-- with "front = local -Z". Rotates the model on top of the slot's own orientation at spawn
-- time; defaults to 0 (no correction) for any tier that doesn't set it.
GameConfig.Brainrots = {
	["Noobini Pizzanini"] = {
		Tier = 1,
		Price = 5,
		EnergyPerDrop = 1,
		DropInterval = 5,
		MergeInto = "Tim Cheese",
		FacingOffset = 180,
	},
	["Tim Cheese"] = {
		Tier = 2,
		Price = 25,
		EnergyPerDrop = 5,
		DropInterval = 5,
		MergeInto = "Trippi Troppi",
		FacingOffset = 180,
	},
	["Trippi Troppi"] = {
		Tier = 3,
		Price = 125,
		EnergyPerDrop = 25,
		DropInterval = 5,
		MergeInto = "Trippi Troppi Troppa Trippa",
		FacingOffset = 180,
	},
	["Trippi Troppi Troppa Trippa"] = {
		Tier = 4,
		Price = 625,
		EnergyPerDrop = 90,
		DropInterval = 5,
		MergeInto = "Cappuccino Assassino",
		FacingOffset = 180,
	},
	["Cappuccino Assassino"] = {
		Tier = 5,
		Price = 3125,
		EnergyPerDrop = 300,
		DropInterval = 5,
		MergeInto = "Chimpanzini Bananini",
		FacingOffset = 180,
	},
	["Chimpanzini Bananini"] = {
		Tier = 6,
		Price = 15625,
		EnergyPerDrop = 1100,
		DropInterval = 5,
		MergeInto = "Bombardiro Crocodilo",
		FacingOffset = 180,
	},
	["Bombardiro Crocodilo"] = {
		Tier = 7,
		Price = 78125,
		EnergyPerDrop = 4000,
		DropInterval = 5,
		MergeInto = "Chimpanzini Spiderini",
		FacingOffset = 180,
	},
	["Chimpanzini Spiderini"] = {
		Tier = 8,
		Price = 390625,
		EnergyPerDrop = 15000,
		DropInterval = 5,
		MergeInto = "Tralalero Tralala",
		FacingOffset = 180,
	},
	["Tralalero Tralala"] = {
		Tier = 9,
		Price = 1953125,
		EnergyPerDrop = 60000,
		DropInterval = 5,
		MergeInto = "Tung Tung Tung Sahur",
		FacingOffset = 180,
	},
	["Tung Tung Tung Sahur"] = {
		Tier = 10,
		Price = 9765625,
		EnergyPerDrop = 235000,
		DropInterval = 5,
		MergeInto = "67",
		FacingOffset = 180,
	},
	["67"] = {
		Tier = 11,
		Price = 48828125,
		EnergyPerDrop = 900000,
		DropInterval = 5,
		MergeInto = "Dragon Cannelloni",
		FacingOffset = 180,
	},
	["Dragon Cannelloni"] = {
		Tier = 12,
		Price = 244140625,
		EnergyPerDrop = 4000000,
		DropInterval = 5,
		MergeInto = "Garama and Madundung",
		FacingOffset = 180,
	},
	["Garama and Madundung"] = {
		Tier = 13,
		Price = 1220703125,
		EnergyPerDrop = 15000000,
		DropInterval = 5,
		MergeInto = "Strawberry Elephant",
		FacingOffset = 180,
	},
	["Strawberry Elephant"] = {
		Tier = 14,
		Price = 6103515625,
		EnergyPerDrop = 55000000,
		DropInterval = 5,
		MergeInto = "La Grande Combinasion",
		FacingOffset = 180,
	},
	["La Grande Combinasion"] = {
		Tier = 15,
		Price = 30517578125,
		EnergyPerDrop = 225000000,
		DropInterval = 5,
		MergeInto = nil, -- max tier for now
		FacingOffset = 180,
	},
}

GameConfig.BrainrotOrder = {
	"Noobini Pizzanini", "Tim Cheese", "Trippi Troppi", "Trippi Troppi Troppa Trippa", "Cappuccino Assassino",
	"Chimpanzini Bananini", "Bombardiro Crocodilo", "Chimpanzini Spiderini", "Tralalero Tralala", "Tung Tung Tung Sahur",
	"67", "Dragon Cannelloni", "Garama and Madundung", "Strawberry Elephant", "La Grande Combinasion",
}

-- Placeholder-model tint per tier, so identical placeholder blocks are still visually
-- distinguishable at a glance until you swap in real models. Generated as an even spread
-- around the color wheel so it automatically covers however many tiers BrainrotOrder has,
-- instead of hand-picking a fixed list of RGB values.
GameConfig.TierColors = {}
for tier = 1, #GameConfig.BrainrotOrder do
	GameConfig.TierColors[tier] = Color3.fromHSV((tier - 1) / #GameConfig.BrainrotOrder, 0.85, 0.95)
end

-- How many of the same tier are needed to merge into the next tier
GameConfig.MergeRequirement = 3

-- ============ SHOP TIER PROGRESSION ============
-- Which brainrot the FollowsShopTier-tagged shop platforms (x1/x5/x25/x100) actually sell is a
-- per-player unlock (data.ShopTier, starts at 1 -- see PlayerDataManager) rather than fixed --
-- pay at the ShopTierUpgradePlatform to raise it by one, up to #BrainrotOrder. The cost of
-- unlocking the NEXT tier is pegged directly to that tier's own Price above (rather than a
-- separate hand-tuned curve), so it automatically follows however Brainrots' Price column gets
-- tuned instead of drifting out of sync with it -- unlocking costs roughly what buying a full
-- x100 at your CURRENT tier would.
GameConfig.ShopTierUpgrade = {
	PriceMultiplier = 100,
}

function GameConfig.GetShopTierUpgradeCost(currentTier: number): number
	local currentBrainrotName = GameConfig.BrainrotOrder[currentTier]
	local currentConfig = currentBrainrotName and GameConfig.Brainrots[currentBrainrotName]
	local price = (currentConfig and currentConfig.Price) or 0
	return math.floor(price * GameConfig.ShopTierUpgrade.PriceMultiplier)
end

-- ============ ENERGY -> COIN CONVERSION ============
-- No cap on the silo -- depositing always moves your entire carried StoredEnergy in at once.
GameConfig.BaseConversionRate = 1

GameConfig.ConversionUpgrade = {
	-- No MaxLevel -- upgrades are purchasable indefinitely, the cost/rate formulas below already
	-- generalize to any level with no cap baked in.
	BaseCost = 1,
	CostGrowth = 1.4,     -- each purchase costs 1.4x the previous one
	RatePerLevel = 0.75,  -- how much the FIRST purchase adds to your rate
	RateGrowth = 1.4,     -- each purchase's rate increase is 1.4x the previous purchase's increase
}

function GameConfig.GetUpgradeCost(currentLevel: number): number
	return math.floor(GameConfig.ConversionUpgrade.BaseCost * (GameConfig.ConversionUpgrade.CostGrowth ^ currentLevel))
end

-- How much rate your NEXT purchase (going from currentLevel to currentLevel + 1) adds --
-- itself growing by RateGrowth each time, not a flat amount.
function GameConfig.GetNextRateIncrease(currentLevel: number): number
	return GameConfig.ConversionUpgrade.RatePerLevel * (GameConfig.ConversionUpgrade.RateGrowth ^ currentLevel)
end

-- Sum of every purchase's increase so far (a geometric series), plus the base rate.
function GameConfig.GetConversionRate(level: number): number
	local upgrade = GameConfig.ConversionUpgrade
	if level <= 0 then
		return GameConfig.BaseConversionRate
	end
	local totalIncrease = upgrade.RatePerLevel * (upgrade.RateGrowth ^ level - 1) / (upgrade.RateGrowth - 1)
	return GameConfig.BaseConversionRate + totalIncrease
end

-- ============ PLOT / CONVEYOR ============
-- 10 columns x 5 rows. BrainrotSpawner derives the grid shape from however many physical
-- BrainrotSlots parts a plot actually has (that's the column count) and this total, so for
-- this to come out as exactly 10x5 each plot needs exactly 10 BrainrotSlots parts built in
-- Studio (see studio-tools/BuildBrainrotGrid.luau) -- ceil(50 / 10) = 5 layers.
GameConfig.MaxBrainrotsPerPlot = 50

-- VERTICAL spacing: studs between each stacked row once every physical BrainrotSlots part
-- already has one brainrot on it. This is the vertical counterpart to DEFAULT_SPACING in
-- studio-tools/BuildBrainrotGrid.luau (horizontal, between columns) -- separate knobs for
-- separate axes, and both separate from that script's per-gap CUSTOM_GAPS overrides.
GameConfig.StackLayerHeight = 10

GameConfig.ConveyorTravelTime = 4

-- ============ NUMBER FORMATTING ============
-- Shared by both client (HUD text) and server (billboard/platform text) so every place a big
-- lump-sum number gets shown -- cash, prices, energy amounts -- uses the same abbreviation
-- rule: plain comma-formatted below 100,000, then K/M/B/T above that -- 1 decimal place in the
-- K range (100,000 -> "100.0K"), 2 decimal places from M upward (5,200,000 -> "5.20M").
local ABBREVIATIONS = {
	{ threshold = 1e12, divisor = 1e12, suffix = "T", decimals = 2 },
	{ threshold = 1e9, divisor = 1e9, suffix = "B", decimals = 2 },
	{ threshold = 1e6, divisor = 1e6, suffix = "M", decimals = 2 },
	{ threshold = 1e5, divisor = 1e3, suffix = "K", decimals = 1 }, -- 100,000 is the cutoff, not 1,000
}

function GameConfig.FormatAbbreviatedNumber(amount: number): string
	local isNegative = amount < 0
	local magnitude = math.abs(amount)

	for _, entry in ipairs(ABBREVIATIONS) do
		if magnitude >= entry.threshold then
			local scaled = magnitude / entry.divisor
			return (isNegative and "-" or "") .. ("%." .. entry.decimals .. "f"):format(scaled) .. entry.suffix
		end
	end

	local digits = tostring(math.floor(magnitude))
	local reversed = digits:reverse():gsub("(%d%d%d)", "%1,"):gsub(",$", "")
	return (isNegative and "-" or "") .. reversed:reverse()
end

-- Same abbreviation above 100,000 as FormatAbbreviatedNumber (both always show 2 decimals
-- there now), but for per-second RATES rather than lump sums -- rates are meaningfully
-- fractional BELOW that threshold too (e.g. "1.75"), so this keeps 2 decimals down there as
-- well instead of falling back to comma-formatted whole numbers.
function GameConfig.FormatAbbreviatedRate(amount: number): string
	if math.abs(amount) >= 1e5 then
		return GameConfig.FormatAbbreviatedNumber(amount)
	end
	return ("%.2f"):format(amount)
end

return GameConfig
