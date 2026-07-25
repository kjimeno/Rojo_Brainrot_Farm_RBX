-- BuildRow1Platforms.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- BrainrotSpawner.addStandPlatform only spawns a placeholder platform under STACKED
-- brainrots (layer 1+, the 2nd row and up) -- row 1 (layer 0) sits directly on the physical
-- BrainrotSlots part, so it never gets one at runtime. This script places a STATIC copy of
-- ServerStorage/StandPlatform under every BrainrotSlots part on every plot, ONCE, as
-- permanent map geometry -- it's not managed, tracked, or destroyed by any runtime script,
-- so it'll be there regardless of whether a brainrot currently occupies that slot (matches
-- rows 2+ visually, which DO get destroyed/recreated on every repack).
--
-- Requires ServerStorage/StandPlatform to already exist (Part or Model, same as the runtime
-- fallback used for rows 2+).
--
-- Safe to re-run: skips any BrainrotSlots part that already has a "Row1Platform" child.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- If true, the original BrainrotSlots part is made invisible/non-collidable once its row-1
-- platform is placed, so you don't see both stacked on top of each other. It's still fully
-- functional underneath (BrainrotSpawner only ever reads its CFrame/Size, never its
-- visibility) -- this is purely cosmetic. Set to false to leave the slot parts visible.
local HIDE_SLOT_AFTER_PLACEMENT = true

local template = ServerStorage:FindFirstChild("StandPlatform")
if not template then
	warn("[BuildRow1Platforms] No ServerStorage.StandPlatform found -- build one first (Part or Model).")
	return
end

local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	warn("[BuildRow1Platforms] No Workspace.Plots folder found.")
	return
end

local function getHeight(instance: Instance): number
	if instance:IsA("Model") then
		return instance:GetExtentsSize().Y
	end
	return (instance :: BasePart).Size.Y
end

local placedCount = 0

for _, plot in ipairs(plotsFolder:GetChildren()) do
	local slotsFolder = plot:FindFirstChild("BrainrotSlots")
	if not slotsFolder then continue end

	for _, slot in ipairs(slotsFolder:GetChildren()) do
		if not slot:IsA("BasePart") then continue end
		if slot:FindFirstChild("Row1Platform") then continue end

		local platform = template:Clone()
		platform.Name = "Row1Platform"

		local height = getHeight(platform)
		local targetCFrame = slot.CFrame * CFrame.new(0, -height / 2, 0)

		if platform:IsA("Model") then
			for _, part in ipairs(platform:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			platform:PivotTo(targetCFrame)
		else
			platform.Anchored = true
			platform.CFrame = targetCFrame
		end

		platform.Parent = slot
		placedCount += 1

		if HIDE_SLOT_AFTER_PLACEMENT then
			slot.Transparency = 1
			slot.CanCollide = false
		end
	end
end

print(("[BuildRow1Platforms] Placed %d row-1 platform(s)"):format(placedCount))
