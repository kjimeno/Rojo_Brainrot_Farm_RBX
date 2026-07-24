-- BuildMergePlatform.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
-- It adds a "MergePlatform" Part to every existing plot under Workspace.Plots
-- (skipping any plot that already has one), positioned just beside that plot's
-- CoinVault/DepositArea so it lands somewhere reasonable — nudge it afterward
-- if it's not exactly where you want it.
--
-- No attributes are set on it: MergeSystem.luau defaults an unattributed
-- MergePlatform to merging tier-1 (Tralalero) brainrots. If you ever add a second
-- merge platform for a different tier, set its "MergeBrainrotName" attribute
-- to that tier's name (e.g. "TrippiTroppi").
--
-- After running it, restart your Play Test / rojo-served session so MergeSystem.luau
-- (which scans for MergePlatforms once at server start) picks it up and attaches
-- the floating "Merge" text.

local Workspace = game:GetService("Workspace")

local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	warn("[MergePlatformBuilder] No Workspace.Plots folder found — build your plots first.")
	return
end

local PLATFORM_SIZE = Vector3.new(6, 1, 6)
local OFFSET_FROM_REFERENCE = Vector3.new(8, 0, 0)

for _, plot in ipairs(plotsFolder:GetChildren()) do
	if plot:FindFirstChild("MergePlatform") then
		print(("[MergePlatformBuilder] %s already has a MergePlatform, skipping"):format(plot.Name))
		continue
	end

	local reference = plot:FindFirstChild("CoinVault") or plot:FindFirstChild("DepositArea")
	local basePosition
	if reference and reference:IsA("BasePart") then
		basePosition = reference.Position + OFFSET_FROM_REFERENCE
	elseif plot:IsA("Model") or plot:IsA("BasePart") then
		local ok, pivot = pcall(function()
			return plot:GetPivot()
		end)
		basePosition = (ok and pivot.Position) or Vector3.new(0, 0.5, 0)
	else
		basePosition = Vector3.new(0, 0.5, 0)
	end

	local platform = Instance.new("Part")
	platform.Name = "MergePlatform"
	platform.Size = PLATFORM_SIZE
	platform.Anchored = true
	platform.Material = Enum.Material.Neon
	platform.Color = Color3.fromRGB(0, 200, 255)
	platform.Position = basePosition
	platform.Parent = plot

	print(("[MergePlatformBuilder] Added MergePlatform to %s at %s -- reposition as needed"):format(plot.Name, tostring(basePosition)))
end
