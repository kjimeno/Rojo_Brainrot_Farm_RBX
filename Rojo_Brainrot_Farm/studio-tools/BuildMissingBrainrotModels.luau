-- BuildMissingBrainrotModels.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- Fills in any ServerStorage/BrainrotModels/<Name> folder that's missing for a name in
-- GameConfig.Brainrots, by cloning whichever placeholder Model already exists there (e.g.
-- your Tralalero block) and renaming the clone. The tier color/tint is applied automatically
-- at spawn time regardless of the model's own geometry (see BrainrotSpawner.colorModelByTier),
-- so reusing the same block for every tier is fine visually -- swap in real models later
-- whenever you want, same folder names.
--
-- Safe to re-run: it only fills in names that don't already have a model, never touches or
-- duplicates ones that already exist.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local modelsFolder = ServerStorage:FindFirstChild("BrainrotModels")
if not modelsFolder then
	warn("[BuildMissingBrainrotModels] No ServerStorage.BrainrotModels folder found -- build at least one placeholder model first.")
	return
end

-- Pick any existing model to use as the template for names that don't have one yet.
local template = nil
for _, child in ipairs(modelsFolder:GetChildren()) do
	if child:IsA("Model") then
		template = child
		break
	end
end

if not template then
	warn("[BuildMissingBrainrotModels] BrainrotModels folder has no existing Model to use as a placeholder template.")
	return
end

local created = {}
for _, brainrotName in ipairs(GameConfig.BrainrotOrder) do
	if not modelsFolder:FindFirstChild(brainrotName) then
		local model = template:Clone()
		model.Name = brainrotName
		model.Parent = modelsFolder
		table.insert(created, brainrotName)
	end
end

if #created > 0 then
	print(("[BuildMissingBrainrotModels] Added placeholder models for: %s"):format(table.concat(created, ", ")))
else
	print("[BuildMissingBrainrotModels] Every brainrot in GameConfig already has a model -- nothing to do.")
end
