-- BuildBrainrotGrid.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- BrainrotSpawner derives the grid's column count from however many physical BrainrotSlots
-- parts a plot has, and the row count from GameConfig.MaxBrainrotsPerPlot / columns (rounded
-- up). GameConfig.MaxBrainrotsPerPlot is now 27, so for the grid to come out as exactly
-- 9 columns x 3 rows, each plot needs EXACTLY 9 BrainrotSlots parts. This script rebuilds
-- each plot's BrainrotSlots folder to have exactly that many, evenly spaced, using your
-- first existing slot as the template (size/material/etc.) and inferring spacing from your
-- first two existing slots if there are at least two.
--
-- WARNING: this destroys your plots' existing BrainrotSlots parts (and any brainrot models
-- currently sitting on them) and replaces them with 9 fresh ones. Player data isn't touched --
-- only the visuals -- so the next merge or purchase will redraw everything correctly at the
-- new 9x3 layout. If you have brainrots you want to see again without buying/merging, trigger
-- a purchase or merge once after running this to force a repack.

local Workspace = game:GetService("Workspace")

local NUM_COLUMNS = 9
local DEFAULT_SPACING = 4 -- studs between columns, used only if we can't infer it from your slots

local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	warn("[BuildBrainrotGrid] No Workspace.Plots folder found.")
	return
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	local slotsFolder = plot:FindFirstChild("BrainrotSlots")
	if not slotsFolder then
		warn(("[BuildBrainrotGrid] %s has no BrainrotSlots folder, skipped"):format(plot.Name))
		continue
	end

	local existing = {}
	for _, slot in ipairs(slotsFolder:GetChildren()) do
		if slot:IsA("BasePart") then
			table.insert(existing, slot)
		end
	end

	if #existing == 0 then
		warn(("[BuildBrainrotGrid] %s's BrainrotSlots has no existing Parts to use as a template, skipped"):format(plot.Name))
		continue
	end

	table.sort(existing, function(a, b)
		return a.Position.X < b.Position.X
	end)

	local origin = existing[1].Position
	local spacing = DEFAULT_SPACING
	if #existing >= 2 then
		spacing = existing[2].Position.X - existing[1].Position.X
	end

	local template = existing[1]:Clone()

	for _, slot in ipairs(existing) do
		slot:Destroy()
	end

	for i = 1, NUM_COLUMNS do
		local slot = template:Clone()
		slot.Name = "Slot" .. i
		slot.Position = origin + Vector3.new(spacing * (i - 1), 0, 0)
		slot.Parent = slotsFolder
	end

	template:Destroy()

	print(("[BuildBrainrotGrid] Rebuilt %s's BrainrotSlots with exactly %d evenly-spaced columns"):format(plot.Name, NUM_COLUMNS))
end
