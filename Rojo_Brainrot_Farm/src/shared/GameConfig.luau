-- GameConfig.luau
-- Lives at ReplicatedStorage.Shared.GameConfig (accessible from client AND server)
-- Single source of truth for balancing.

local GameConfig = {}

-- ============ BRAINROT TIERS ============
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
		MergeInto = nil, -- max tier for now
	},
}

GameConfig.BrainrotOrder = {
	"Tralalero", "TrippiTroppi", "BombardiroCrocodilo", "CappuccinoAssassino", "TungTungSahur",
}

-- How many of the same tier are needed to merge into the next tier
GameConfig.MergeRequirement = 3

-- ============ ENERGY -> COIN CONVERSION ============
GameConfig.BaseConversionRate = 1
GameConfig.MaxSiloCapacity = 500

GameConfig.ConversionUpgrade = {
	MaxLevel = 20,
	BaseCost = 750,
	CostGrowth = 1.4,
	RatePerLevel = 0.75,
}

function GameConfig.GetUpgradeCost(currentLevel: number): number
	return math.floor(GameConfig.ConversionUpgrade.BaseCost * (GameConfig.ConversionUpgrade.CostGrowth ^ currentLevel))
end

function GameConfig.GetConversionRate(level: number): number
	return GameConfig.BaseConversionRate + (level * GameConfig.ConversionUpgrade.RatePerLevel)
end

-- ============ PLOT / CONVEYOR ============
GameConfig.MaxBrainrotsPerPlot = 12
GameConfig.ConveyorTravelTime = 4

return GameConfig
