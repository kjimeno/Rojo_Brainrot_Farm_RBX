-- FixShopPlatformNames.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- Your existing shop platforms (built before the brainrot tier rename) still have their
-- BrainrotName attribute set to the OLD tier-1 name ("Tralalero"), which no longer matches
-- anything in GameConfig.Brainrots -- hence "Invalid brainrot" when trying to buy from them.
-- This finds every instance anywhere in the workspace with BrainrotName == an old name and
-- updates it to the matching new name.
--
-- Safe to re-run: only touches instances still carrying an old name.

local Workspace = game:GetService("Workspace")

local OLD_TO_NEW = {
	["Tralalero"] = "Noobini Pizzanini",
	["TrippiTroppi"] = "Tim Cheese",
	["BombardiroCrocodilo"] = "Trippi Troppi",
	["CappuccinoAssassino"] = "Trippi Troppi Troppa Trippa",
	["TungTungSahur"] = "Cappuccino Assassino",
	["BrrBrrPatapim"] = "Chimpanzini Bananini",
	["LiriliLarila"] = "Bombardiro Crocodilo",
	["ChimpanziniBananini"] = "Chimpanzini Spiderini",
	["BombombiniGusini"] = "Tralalero Tralala",
	["TrulimeroTrulicina"] = "Tung Tung Tung Sahur",
	["OdinDinDinDun"] = "67",
	["BonecaAmbalabu"] = "Dragon Cannelloni",
	["FrigoCamelo"] = "Garama and Madundung",
	["GirafaCelestre"] = "Strawberry Elephant",
	["TrenostruzzoTurbo"] = "La Grande Combinasion",
}

local fixedCount = 0

for _, instance in ipairs(Workspace:GetDescendants()) do
	local currentName = instance:GetAttribute("BrainrotName")
	local newName = currentName and OLD_TO_NEW[currentName]
	if newName then
		instance:SetAttribute("BrainrotName", newName)
		fixedCount += 1
		print(("[FixShopPlatformNames] %s: %q -> %q"):format(instance:GetFullName(), currentName, newName))
	end
end

print(("[FixShopPlatformNames] Fixed %d instance(s)."):format(fixedCount))
