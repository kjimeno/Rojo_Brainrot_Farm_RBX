-- MoveBrainrotSlots.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
-- Shifts every plot's "BrainrotSlots" folder (the grid where brainrots spawn/stack)
-- by 20 studs along +Z, pushing it away from spawn. Also shifts any brainrot models
-- already sitting in those slots (from previous testing) so nothing gets left behind.
--
-- Re-run safely any time you want to nudge it again by another 20 studs -- it's a
-- relative shift, not an absolute reposition.

local Workspace = game:GetService("Workspace")

local OFFSET = Vector3.new(0, 0, 20)

local plotsFolder = Workspace:FindFirstChild("Plots")
if not plotsFolder then
	warn("[MoveBrainrotSlots] No Workspace.Plots folder found.")
	return
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	local slotsFolder = plot:FindFirstChild("BrainrotSlots")
	if not slotsFolder then
		warn(("[MoveBrainrotSlots] %s has no BrainrotSlots folder, skipped"):format(plot.Name))
		continue
	end

	for _, slot in ipairs(slotsFolder:GetChildren()) do
		if not slot:IsA("BasePart") then continue end

		-- Move any brainrot models already sitting on this slot (from previous testing)
		-- along with it, so they don't get left behind at the old position.
		for _, child in ipairs(slot:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("BrainrotId") ~= nil then
				child:PivotTo(child:GetPivot() + OFFSET)
			end
		end

		slot.CFrame = slot.CFrame + OFFSET
	end

	print(("[MoveBrainrotSlots] Shifted %s's BrainrotSlots by %s"):format(plot.Name, tostring(OFFSET)))
end
