-- CenterEnergyFrame.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- Centers StarterGui.Main.HUD.Up horizontally and anchors it to the top of the screen,
-- keeping whatever vertical (Y) offset it already has -- only the horizontal centering and
-- top-anchoring changes.

local StarterGui = game:GetService("StarterGui")

local main = StarterGui:FindFirstChild("Main")
if not main then
	warn("[CenterEnergyFrame] No StarterGui.Main found.")
	return
end

local hud = main:FindFirstChild("HUD")
if not hud then
	warn("[CenterEnergyFrame] No Main.HUD found.")
	return
end

local upFrame = hud:FindFirstChild("Up")
if not upFrame then
	warn("[CenterEnergyFrame] No HUD.Up found.")
	return
end

local currentPosition = upFrame.Position
upFrame.AnchorPoint = Vector2.new(0.5, 0)
upFrame.Position = UDim2.new(0.5, 0, currentPosition.Y.Scale, currentPosition.Y.Offset)

print("[CenterEnergyFrame] Centered HUD.Up horizontally at the top.")
