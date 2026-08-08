-- GameConfig.luau
-- Lives at ReplicatedStorage.Shared.GameConfig (accessible from client AND server)
-- Single source of truth for balancing.

local GameConfig = {}

-- ============ BRAINROT TIERS ============
-- Tiers 1-3 are untouched on purpose -- that's the pacing you said felt right. From tier 3
-- onward, two different curves both get steeper instead of continuing tier 1-3's flat ratios:
--
-- EnergyPerDrop: a flat 3.2x per tier from here on (tiers 1-3 keep their original ~5x jumps).
-- MergeRequirement copies of one tier merge into the next, so this ratio IS the merge economy:
-- at the old ~3.6-5x-per-tier curve, merging 3 brainrots into 1 handed you a 20-67% bonus over
-- what you fed in, and that bonus is what compounds into a runaway snowball the more you merge.
-- At 3.2x, merging 3 gives you only ~7% more than you put in -- real but modest progress,
-- instead of every merge multiplying your income. Since this compounds tier over tier, a small
-- per-tier change barely moves early numbers but adds up to a huge gap by tier 8+.
--
-- Price: tiers 1-3 keep the flat 5x jump. From tier 3 on, the RATIO itself climbs every tier
-- (6x, 7x, 8x, ... 17x) instead of staying flat at 5x forever -- true acceleration, so buying
-- into a new tier gets disproportionately more expensive the further you go, not just bigger.
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
		Price = 750, -- 125 x 6
		EnergyPerDrop = 80, -- 25 x 3.2
		DropInterval = 5,
		MergeInto = "Cappuccino Assassino",
		FacingOffset = 180,
	},
	["Cappuccino Assassino"] = {
		Tier = 5,
		Price = 5250, -- 750 x 7
		EnergyPerDrop = 256, -- 80 x 3.2
		DropInterval = 5,
		MergeInto = "Chimpanzini Bananini",
		FacingOffset = 180,
	},
	["Chimpanzini Bananini"] = {
		Tier = 6,
		Price = 42000, -- 5250 x 8
		EnergyPerDrop = 819, -- 256 x 3.2
		DropInterval = 5,
		MergeInto = "Bombardiro Crocodilo",
		FacingOffset = 180,
	},
	["Bombardiro Crocodilo"] = {
		Tier = 7,
		Price = 378000, -- 42000 x 9
		EnergyPerDrop = 2621, -- 819 x 3.2
		DropInterval = 5,
		MergeInto = "Chimpanzini Spiderini",
		FacingOffset = 180,
	},
	["Chimpanzini Spiderini"] = {
		Tier = 8,
		Price = 3780000, -- 378000 x 10
		EnergyPerDrop = 8387, -- 2621 x 3.2
		DropInterval = 5,
		MergeInto = "Tralalero Tralala",
		FacingOffset = 180,
	},
	["Tralalero Tralala"] = {
		Tier = 9,
		Price = 41580000, -- 3780000 x 11
		EnergyPerDrop = 26838, -- 8387 x 3.2
		DropInterval = 5,
		MergeInto = "Tung Tung Tung Sahur",
		FacingOffset = 180,
	},
	["Tung Tung Tung Sahur"] = {
		Tier = 10,
		Price = 498960000, -- 41580000 x 12
		EnergyPerDrop = 85882, -- 26838 x 3.2
		DropInterval = 5,
		MergeInto = "67",
		FacingOffset = 180,
	},
	["67"] = {
		Tier = 11,
		Price = 6486480000, -- 498960000 x 13
		EnergyPerDrop = 274822, -- 85882 x 3.2
		DropInterval = 5,
		MergeInto = "Dragon Cannelloni",
		FacingOffset = 180,
	},
	["Dragon Cannelloni"] = {
		Tier = 12,
		Price = 90810720000, -- 6486480000 x 14
		EnergyPerDrop = 879430, -- 274822 x 3.2
		DropInterval = 5,
		MergeInto = "Garama and Madundung",
		FacingOffset = 180,
	},
	["Garama and Madundung"] = {
		Tier = 13,
		Price = 1362160800000, -- 90810720000 x 15
		EnergyPerDrop = 2814176, -- 879430 x 3.2
		DropInterval = 5,
		MergeInto = "Strawberry Elephant",
		FacingOffset = 180,
	},
	["Strawberry Elephant"] = {
		Tier = 14,
		Price = 21794572800000, -- 1362160800000 x 16
		EnergyPerDrop = 9005363, -- 2814176 x 3.2
		DropInterval = 5,
		MergeInto = "La Grande Combinasion",
		FacingOffset = 180,
	},
	["La Grande Combinasion"] = {
		Tier = 15,
		Price = 370507737600000, -- 21794572800000 x 17
		EnergyPerDrop = 28817162, -- 9005363 x 3.2
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

-- ============ NET WORTH-SCALED PRICING ============
-- "Total brainrot value": each owned brainrot is worth 3^(Tier-1) -- tier 1 = 1, tier 2 = 3,
-- tier 3 = 9, and so on. That exponent isn't arbitrary: MergeRequirement (3) copies of one tier
-- always merge into exactly 1 of the next, and 3 x 3^(N-1) = 3^N -- so merging can NEVER change
-- this total, only buying more brainrots can. It's a clean read on "how powerful is this player
-- right now" that isn't gamed by however many times they've merged.
--
-- Both brainrot prices and the conversion-rate upgrade cost scale off this value through a
-- shared multiplier -- the more of a portfolio a player has already built, the more everything
-- costs from here, regardless of which tier or strategy they leaned on to get there. A single
-- snapshot taken once per purchase (not recalculated per-unit inside one bulk buy), so buying
-- x100 at once doesn't spiral the way per-unit purchase-count pricing did.
function GameConfig.GetTotalBrainrotValue(ownedBrainrots: { { Name: string, Id: string } }): number
	local total = 0
	for _, entry in ipairs(ownedBrainrots) do
		local config = GameConfig.Brainrots[entry.Name]
		if config then
			total += 3 ^ (config.Tier - 1)
		end
	end
	return total
end

-- Multiplier = 1 + Rate * totalValue -- LINEAR in totalValue, not a power curve. A power curve
-- (anything ^ Exponent < 1) keeps getting flatter forever, so eventually one more purchase adds
-- less than $1 and the rounded price repeats itself -- not a tuning issue, just what that shape
-- of curve inevitably does once totalValue gets big enough. Linear keeps a CONSTANT per-purchase
-- increment instead of a shrinking one, so at Rate = 0.288 that increment for tier 1 (base $5) is
-- 5 x 0.288 = $1.44 -- always over $1, which mathematically guarantees two consecutive purchases
-- can never round to the same price. Buying tier 1 repeatedly: $5, $7, $9, $10, $12, $13, $15...
-- Only affects brainrot pricing -- GetUpgradeCost (rate-per-second) deliberately does NOT use
-- this, so the two stay independent even though they share this same underlying reading.
GameConfig.ValueScaling = {
	Rate = 0.288,
}

function GameConfig.GetValueScaledMultiplier(totalValue: number): number
	return 1 + GameConfig.ValueScaling.Rate * totalValue
end

-- Price of ONE unit of `brainrotName` right now, given the player's current total brainrot value.
function GameConfig.GetBrainrotUnitPrice(brainrotName: string, totalValue: number): number
	local config = GameConfig.Brainrots[brainrotName]
	if not config then return 0 end
	local price = config.Price * GameConfig.GetValueScaledMultiplier(totalValue)
	return math.floor(price + 0.5)
end

-- Total cost of buying `quantity` units in one go, all at the SAME per-unit price (today's
-- value-scaled price, taken once) -- not escalating unit-by-unit within the purchase, so x100
-- stays a predictable "100x the current price" rather than compounding mid-transaction.
function GameConfig.GetBrainrotBulkPrice(brainrotName: string, totalValue: number, quantity: number): number
	return GameConfig.GetBrainrotUnitPrice(brainrotName, totalValue) * quantity
end

-- ============ SHOP TIER PROGRESSION ============
-- Which brainrot the FollowsShopTier-tagged shop platforms (x1/x5/x25/x100) actually sell is a
-- per-player unlock (data.ShopTier, starts at 1 -- see PlayerDataManager) rather than fixed --
-- pay at the ShopTierUpgradePlatform to raise it by one, up to #BrainrotOrder. The cost of
-- unlocking the NEXT tier is pegged directly to that tier's own Price above (a flat constant
-- multiplier, not its own separate growing curve) so it automatically follows however Brainrots'
-- Price column gets tuned instead of drifting out of sync with it -- and since Price above now
-- accelerates from tier 3 onward, this cost inherits that same acceleration for free. The
-- multiplier itself was also raised (100 -> 300) to make unlocking a real, deliberate sink on
-- top of that, not just along for the ride.
GameConfig.ShopTierUpgrade = {
	PriceMultiplier = 300,
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
	--
	-- Cost is a power curve, NOT exponential -- cost(level) = CostBase * (level + CostOffset) ^
	-- CostExponent. Consecutive-purchase cost RATIOS start high (~1.6-2.1x) and steadily decay
	-- toward ~1.14x as level climbs -- a constant-ratio (exponential) curve can't do that, its
	-- ratio never changes. These three constants were fit to hit level 0 = $10 and level 22 =
	-- $4238 exactly, landing within a few percent through the rest of the range.
	CostBase = 0.0886,
	CostOffset = 4.187,
	CostExponent = 3.3,
	RatePerLevel = 0.75,  -- how much the FIRST purchase adds to your rate
	RateGrowth = 1.25,    -- each purchase's rate increase is 1.25x the previous purchase's increase (was 1.4 -- the granted rate itself was compounding too fast, independent of cost)
}

-- Deliberately independent of GetTotalBrainrotValue (unlike brainrot pricing above) -- this
-- still gets more expensive as you buy more of it, just not also taxed by how big your
-- brainrot portfolio is.
function GameConfig.GetUpgradeCost(currentLevel: number): number
	local upgrade = GameConfig.ConversionUpgrade
	local cost = upgrade.CostBase * ((currentLevel + upgrade.CostOffset) ^ upgrade.CostExponent)
	return math.floor(cost + 0.5)
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
