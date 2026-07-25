-- GameConfig.luau
-- Lives at ReplicatedStorage.Shared.GameConfig (accessible from client AND server)
-- Single source of truth for balancing.

local GameConfig = {}

-- ============ BRAINROT TIERS ============
-- Names/prices/drop rates below are placeholders like everything else so far -- swap them
-- for whatever real "brainrot" names/balancing you want later. Price keeps the x5-per-tier
-- pattern you set for tiers 1-5; EnergyPerDrop keeps roughly the same ~2.5x-per-tier curve.
GameConfig.Brainrots = {
	["Tralalero"] = {
		Tier = 1,
		Price = 5,
		EnergyPerDrop = 1,
		DropInterval = 3,
		MergeInto = "TrippiTroppi",
	},
	["TrippiTroppi"] = {
		Tier = 2,
		Price = 25,
		EnergyPerDrop = 3,
		DropInterval = 3,
		MergeInto = "BombardiroCrocodilo",
	},
	["BombardiroCrocodilo"] = {
		Tier = 3,
		Price = 125,
		EnergyPerDrop = 8,
		DropInterval = 3,
		MergeInto = "CappuccinoAssassino",
	},
	["CappuccinoAssassino"] = {
		Tier = 4,
		Price = 625,
		EnergyPerDrop = 20,
		DropInterval = 3,
		MergeInto = "TungTungSahur",
	},
	["TungTungSahur"] = {
		Tier = 5,
		Price = 3125,
		EnergyPerDrop = 50,
		DropInterval = 3,
		MergeInto = "BrrBrrPatapim",
	},
	["BrrBrrPatapim"] = {
		Tier = 6,
		Price = 15625,
		EnergyPerDrop = 125,
		DropInterval = 3,
		MergeInto = "LiriliLarila",
	},
	["LiriliLarila"] = {
		Tier = 7,
		Price = 78125,
		EnergyPerDrop = 310,
		DropInterval = 3,
		MergeInto = "ChimpanziniBananini",
	},
	["ChimpanziniBananini"] = {
		Tier = 8,
		Price = 390625,
		EnergyPerDrop = 780,
		DropInterval = 3,
		MergeInto = "BombombiniGusini",
	},
	["BombombiniGusini"] = {
		Tier = 9,
		Price = 1953125,
		EnergyPerDrop = 1950,
		DropInterval = 3,
		MergeInto = "TrulimeroTrulicina",
	},
	["TrulimeroTrulicina"] = {
		Tier = 10,
		Price = 9765625,
		EnergyPerDrop = 4900,
		DropInterval = 3,
		MergeInto = "OdinDinDinDun",
	},
	["OdinDinDinDun"] = {
		Tier = 11,
		Price = 48828125,
		EnergyPerDrop = 12250,
		DropInterval = 3,
		MergeInto = "BonecaAmbalabu",
	},
	["BonecaAmbalabu"] = {
		Tier = 12,
		Price = 244140625,
		EnergyPerDrop = 30600,
		DropInterval = 3,
		MergeInto = "FrigoCamelo",
	},
	["FrigoCamelo"] = {
		Tier = 13,
		Price = 1220703125,
		EnergyPerDrop = 76500,
		DropInterval = 3,
		MergeInto = "GirafaCelestre",
	},
	["GirafaCelestre"] = {
		Tier = 14,
		Price = 6103515625,
		EnergyPerDrop = 191000,
		DropInterval = 3,
		MergeInto = "TrenostruzzoTurbo",
	},
	["TrenostruzzoTurbo"] = {
		Tier = 15,
		Price = 30517578125,
		EnergyPerDrop = 478000,
		DropInterval = 3,
		MergeInto = nil, -- max tier for now
	},
}

GameConfig.BrainrotOrder = {
	"Tralalero", "TrippiTroppi", "BombardiroCrocodilo", "CappuccinoAssassino", "TungTungSahur",
	"BrrBrrPatapim", "LiriliLarila", "ChimpanziniBananini", "BombombiniGusini", "TrulimeroTrulicina",
	"OdinDinDinDun", "BonecaAmbalabu", "FrigoCamelo", "GirafaCelestre", "TrenostruzzoTurbo",
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

-- ============ ENERGY -> COIN CONVERSION ============
-- No cap on the silo -- depositing always moves your entire carried StoredEnergy in at once.
GameConfig.BaseConversionRate = 1

GameConfig.ConversionUpgrade = {
	MaxLevel = 20,
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
-- 9 columns x 4 rows. BrainrotSpawner derives the grid shape from however many physical
-- BrainrotSlots parts a plot actually has (that's the column count) and this total, so for
-- this to come out as exactly 9x4 each plot needs exactly 9 BrainrotSlots parts built in
-- Studio (see studio-tools/BuildBrainrotGrid.luau) -- ceil(36 / 9) = 4 layers.
GameConfig.MaxBrainrotsPerPlot = 36

-- VERTICAL spacing: studs between each stacked row once every physical BrainrotSlots part
-- already has one brainrot on it. This is the vertical counterpart to DEFAULT_SPACING in
-- studio-tools/BuildBrainrotGrid.luau (horizontal, between columns) -- separate knobs for
-- separate axes, and both separate from that script's per-gap CUSTOM_GAPS overrides.
GameConfig.StackLayerHeight = 4

GameConfig.ConveyorTravelTime = 4

return GameConfig
