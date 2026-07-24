-- BuildTieredEnergyParts.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- Note: BrainrotSpawner already tints whichever energy part it spawns using
-- GameConfig.TierColors, so tier-distinct COLOR works right now with zero Studio setup --
-- this script is only for when you're ready to give each tier a genuinely distinct SHAPE
-- (your own 3D models), not just a color.
--
-- Creates ServerStorage/EnergyModels/Tier1 .. Tier<N> (one per tier in GameConfig.Brainrots),
-- each a clone of your existing ServerStorage/EnergyPart, pre-tinted per tier as a starting
-- point. Once built, BrainrotSpawner automatically drops that specific tier's part instead of
-- the shared EnergyPart -- just replace each Tier<N> part's shape/mesh with your real model
-- whenever you're ready (keep it a Part, not a Model -- energy pickups use .CFrame/.Touched
-- directly).
--
-- Safe to re-run: only fills in tiers that don't already have one, never touches existing ones.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local energyPartTemplate = ServerStorage:FindFirstChild("EnergyPart")
if not energyPartTemplate then
	warn("[BuildTieredEnergyParts] No ServerStorage.EnergyPart found -- build that first (a single Part representing one unit of energy).")
	return
end

local energyModelsFolder = ServerStorage:FindFirstChild("EnergyModels")
if not energyModelsFolder then
	energyModelsFolder = Instance.new("Folder")
	energyModelsFolder.Name = "EnergyModels"
	energyModelsFolder.Parent = ServerStorage
end

local created = {}
for _, brainrotName in ipairs(GameConfig.BrainrotOrder) do
	local tier = GameConfig.Brainrots[brainrotName].Tier
	local tierName = "Tier" .. tostring(tier)

	if not energyModelsFolder:FindFirstChild(tierName) then
		local part = energyPartTemplate:Clone()
		part.Name = tierName

		local color = GameConfig.TierColors[tier]
		if color and part:IsA("BasePart") then
			part.Color = color
		end

		part.Parent = energyModelsFolder
		table.insert(created, tierName)
	end
end

if #created > 0 then
	print(("[BuildTieredEnergyParts] Added placeholder energy parts for: %s"):format(table.concat(created, ", ")))
else
	print("[BuildTieredEnergyParts] Every tier already has an energy part -- nothing to do.")
end
