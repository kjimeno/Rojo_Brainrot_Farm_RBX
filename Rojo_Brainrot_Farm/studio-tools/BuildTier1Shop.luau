-- BuildTier1Shop.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
-- It builds 4 SEPARATE small platforms under Workspace.Shop, each with its own
-- ProximityPrompt already tagged with the right BrainrotName/Quantity attributes,
-- replacing the single long block. Delete your old shared shop block first.
--
-- After running it, restart your Play Test / rojo-served session so ShopPrompts.luau
-- (which scans for prompts once at server start) picks up the new platforms and
-- attaches their floating "Buy Nx / price" text.

local Workspace = game:GetService("Workspace")

local shopFolder = Workspace:FindFirstChild("Shop")
if not shopFolder then
	shopFolder = Instance.new("Folder")
	shopFolder.Name = "Shop"
	shopFolder.Parent = Workspace
end

local PLATFORM_SIZE = Vector3.new(6, 1, 6)
local SPACING = 8
-- Edit this to wherever you want the row of 4 platforms to start.
local BASE_POSITION = Vector3.new(0, 0.5, 0)

local QUANTITIES = { 1, 5, 25, 100 }

for i, quantity in ipairs(QUANTITIES) do
	local platform = Instance.new("Part")
	platform.Name = ("Tier1Shop_%dx"):format(quantity)
	platform.Size = PLATFORM_SIZE
	platform.Anchored = true
	platform.Material = Enum.Material.Neon
	platform.Color = Color3.fromRGB(170, 0, 255)
	platform.Position = BASE_POSITION + Vector3.new((i - 1) * SPACING, 0, 0)
	platform.Parent = shopFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = ("%dx Tralalero"):format(quantity)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt:SetAttribute("BrainrotName", "Tralalero")
	prompt:SetAttribute("Quantity", quantity)
	prompt.Parent = platform
end

print("[ShopBuilder] Built 4 separate Tier-1 shop platforms under Workspace.Shop")
