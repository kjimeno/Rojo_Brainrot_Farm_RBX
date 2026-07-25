-- BuildBrainrotGrid.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- BrainrotSpawner derives the grid's column count from however many physical BrainrotSlots
-- parts a plot has, and the row count from GameConfig.MaxBrainrotsPerPlot / columns (rounded
-- up). GameConfig.MaxBrainrotsPerPlot is now 36, so for the grid to come out as exactly
-- 12 columns x 3 rows, each plot needs EXACTLY 12 BrainrotSlots parts. This script rebuilds
-- each plot's BrainrotSlots folder to have exactly that many, using your first existing slot
-- as the template (size/material/etc.) -- or DEFAULT_TEMPLATE_SIZE/COLOR below if that
-- BrainrotSlots folder is currently empty.
--
-- Spacing between columns is NOT required to be uniform -- BrainrotSpawner just sorts
-- whatever slots exist by their live world X position, it doesn't assume any particular gap.
-- CUSTOM_GAPS below lets you widen (or narrow) specific gaps; every other gap uses
-- DEFAULT_SPACING. Gap N is the space between column N and column N+1 -- e.g. CUSTOM_GAPS[4]
-- is the gap between column 4 and column 5.
--
-- WARNING: this destroys your plots' existing BrainrotSlots parts (and any brainrot models
-- currently sitting on them) and replaces them with 12 fresh ones. Player data isn't touched --
-- only the visuals -- so the next merge or purchase will redraw everything correctly at the
-- new layout. If you have brainrots you want to see again without buying/merging, trigger a
-- purchase or merge once after running this to force a repack.

local Workspace = game:GetService("Workspace")

local NUM_COLUMNS = 12
local DEFAULT_SPACING = 8 -- studs between columns, for any gap not listed in CUSTOM_GAPS

-- Used ONLY when a plot's BrainrotSlots folder is completely empty (nothing to clone as a
-- template from). Edit to taste, or just build one Part by hand in BrainrotSlots before
-- running this script and it'll use that instead.
local DEFAULT_TEMPLATE_SIZE = Vector3.new(4, 1, 4)
local DEFAULT_TEMPLATE_COLOR = Color3.fromRGB(163, 162, 165)

-- Edit these to change specific gaps. Gap N = space between column N and column N+1.
local CUSTOM_GAPS = {
	[4] = 15, -- between column 4 and column 5
	[8] = 15, -- between column 8 and column 9
}

-- Columns 5-8 stay on the straight reference line; columns 1-4 and 9-12 each bend away from it
-- by WING_ANGLE_DEGREES, mirrored so both sides are symmetric (a "V"/fan shape). 0 = perfectly
-- straight, same as before this feature existed. Flip the sign if it bends the wrong way once
-- you see it in Studio. This 4/4/4 split lines up with the CUSTOM_GAPS boundaries above (4-5
-- and 8-9) -- if you change those gap positions, update these three lists to match; they must
-- partition 1..NUM_COLUMNS between them.
local WING_ANGLE_DEGREES = 30
local LEFT_WING_COLUMNS = { 1, 2, 3, 4 }
local MIDDLE_COLUMNS = { 5, 6, 7, 8 }
local RIGHT_WING_COLUMNS = { 9, 10, 11, 12 }

-- Per-column XZ-plane offset from the first column (Y always 0), and how many degrees that
-- column's own facing should rotate (0 for the straight middle, +-WING_ANGLE_DEGREES for the
-- wings) so the slot's ORIENTATION bends outward too, not just its position -- brainrot
-- models placed on it (and their energy drops, which spawn relative to the model's own facing
-- direction) will actually face outward along the wing instead of all facing forward.
local function computeColumnLayout(): ({ [number]: Vector3 }, { [number]: number })
	local straightOffsets = { [1] = 0 }
	local x = 0
	for i = 2, NUM_COLUMNS do
		local gapIndex = i - 1
		x += CUSTOM_GAPS[gapIndex] or DEFAULT_SPACING
		straightOffsets[i] = x
	end

	local offsets = {}
	local rotations = {}

	for _, col in ipairs(MIDDLE_COLUMNS) do
		offsets[col] = Vector3.new(straightOffsets[col], 0, 0)
		rotations[col] = 0
	end

	local leftPivotCol = MIDDLE_COLUMNS[1]
	local leftRotation = CFrame.Angles(0, math.rad(WING_ANGLE_DEGREES), 0)
	for _, col in ipairs(LEFT_WING_COLUMNS) do
		local distanceFromPivot = straightOffsets[col] - straightOffsets[leftPivotCol]
		offsets[col] = offsets[leftPivotCol] + (leftRotation * Vector3.new(distanceFromPivot, 0, 0))
		rotations[col] = WING_ANGLE_DEGREES
	end

	local rightPivotCol = MIDDLE_COLUMNS[#MIDDLE_COLUMNS]
	local rightRotation = CFrame.Angles(0, -math.rad(WING_ANGLE_DEGREES), 0)
	for _, col in ipairs(RIGHT_WING_COLUMNS) do
		local distanceFromPivot = straightOffsets[col] - straightOffsets[rightPivotCol]
		offsets[col] = offsets[rightPivotCol] + (rightRotation * Vector3.new(distanceFromPivot, 0, 0))
		rotations[col] = -WING_ANGLE_DEGREES
	end

	return offsets, rotations
end

local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	warn("[BuildBrainrotGrid] No Workspace.Plots folder found.")
	return
end

local columnOffsets, columnRotations = computeColumnLayout()

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

	local origin: Vector3
	local template: BasePart

	if #existing > 0 then
		table.sort(existing, function(a, b)
			return a.Position.X < b.Position.X
		end)

		origin = existing[1].Position
		template = existing[1]:Clone()

		for _, slot in ipairs(existing) do
			slot:Destroy()
		end
	else
		-- Nothing to clone -- fall back to a plain default Part instead of skipping the plot.
		-- Position it at the plot's own pivot if we can get one, otherwise the world origin --
		-- you'll likely want to nudge the whole BrainrotSlots folder afterward either way.
		local ok, pivot = pcall(function()
			return plot:GetPivot()
		end)
		origin = (ok and pivot.Position) or Vector3.new(0, 5, 0)

		template = Instance.new("Part")
		template.Size = DEFAULT_TEMPLATE_SIZE
		template.Anchored = true
		template.Color = DEFAULT_TEMPLATE_COLOR

		warn(("[BuildBrainrotGrid] %s's BrainrotSlots was empty -- used a default Part as the template instead"):format(plot.Name))
	end

	-- Rotation-only part of the template's original CFrame (whatever direction it was already
	-- facing), so the wing rotation gets layered on top of that instead of overwriting it.
	local templateRotation = template.CFrame.Rotation

	for i = 1, NUM_COLUMNS do
		local slot = template:Clone()
		slot.Name = "Slot" .. i
		local extraRotation = CFrame.Angles(0, math.rad(columnRotations[i]), 0)
		slot.CFrame = CFrame.new(origin + columnOffsets[i]) * templateRotation * extraRotation
		slot.Parent = slotsFolder
	end

	template:Destroy()

	local customGapKeys = {}
	for gapIndex in pairs(CUSTOM_GAPS) do
		table.insert(customGapKeys, tostring(gapIndex))
	end
	table.sort(customGapKeys)

	print(("[BuildBrainrotGrid] Rebuilt %s's BrainrotSlots with %d columns (custom spacing at gaps: %s)"):format(
		plot.Name, NUM_COLUMNS, table.concat(customGapKeys, ", ")
	))
end
