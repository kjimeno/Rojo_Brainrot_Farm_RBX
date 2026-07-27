-- RenameBrainrotModels.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- The brainrot tier names were renamed in GameConfig.luau. Your existing
-- ServerStorage/BrainrotModels/<Name> folders are still named after the OLD tier names, so
-- the game currently can't find any of them (BrainrotSpawner will warn "No
-- ServerStorage/BrainrotModels/<new name> found" for every tier). This renames each existing
-- model in place, old name -> new name, by tier position (tier 1's model gets renamed to
-- whatever tier 1 is called now, etc.) -- same trick used for the EnergyModels/Tier<N>
-- folder, except those are already keyed by tier NUMBER so they didn't need this.
--
-- Safe to re-run: only renames a model if it's still sitting under its OLD name; already-
-- renamed or missing ones are skipped with a message.

local ServerStorage = game:GetService("ServerStorage")

local OLD_NAMES = {
	"Tralalero", "TrippiTroppi", "BombardiroCrocodilo", "CappuccinoAssassino", "TungTungSahur",
	"BrrBrrPatapim", "LiriliLarila", "ChimpanziniBananini", "BombombiniGusini", "TrulimeroTrulicina",
	"OdinDinDinDun", "BonecaAmbalabu", "FrigoCamelo", "GirafaCelestre", "TrenostruzzoTurbo",
}

local NEW_NAMES = {
	"Noobini Pizzanini", "Tim Cheese", "Trippi Troppi", "Trippi Troppi Troppa Trippa", "Cappuccino Assassino",
	"Chimpanzini Bananini", "Bombardiro Crocodilo", "Chimpanzini Spiderini", "Tralalero Tralala", "Tung Tung Tung Sahur",
	"67", "Dragon Cannelloni", "Garama and Madundung", "Strawberry Elephant", "La Grande Combinasion",
}

local modelsFolder = ServerStorage:FindFirstChild("BrainrotModels")
if not modelsFolder then
	warn("[RenameBrainrotModels] No ServerStorage.BrainrotModels folder found.")
	return
end

for i, oldName in ipairs(OLD_NAMES) do
	local newName = NEW_NAMES[i]
	local model = modelsFolder:FindFirstChild(oldName)

	if model then
		model.Name = newName
		print(("[RenameBrainrotModels] Renamed %q -> %q"):format(oldName, newName))
	elseif modelsFolder:FindFirstChild(newName) then
		print(("[RenameBrainrotModels] %q already exists, skipping"):format(newName))
	else
		warn(("[RenameBrainrotModels] Neither %q nor %q found, skipping"):format(oldName, newName))
	end
end
