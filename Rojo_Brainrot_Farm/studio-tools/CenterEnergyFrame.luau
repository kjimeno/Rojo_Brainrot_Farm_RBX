-- CenterEnergyFrame.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- Centers HUD.Up horizontally AND centers HUD.Up.Icon horizontally within it -- the frame being
-- centered isn't enough if the Icon inside it also has its own off-center AnchorPoint/Position,
-- which is the likely reason it still LOOKED off-center after the first pass of this script.
-- Keeps whatever vertical (Y) position each already has -- only horizontal centering changes.
--
-- Applies to StarterGui.Main (so it's fixed for every future spawn) AND, if you're running this
-- while in Play mode, every currently-connected player's live PlayerGui.Main too, so you can see
-- the fix immediately without needing to stop and restart the test.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local function centerUpFrame(main: Instance, label: string)
	local hud = main:FindFirstChild("HUD")
	if not hud then
		warn(("[CenterEnergyFrame] No HUD found under %s."):format(label))
		return
	end

	local upFrame = hud:FindFirstChild("Up")
	if not upFrame then
		warn(("[CenterEnergyFrame] No HUD.Up found under %s."):format(label))
		return
	end

	local upPosition = upFrame.Position
	upFrame.AnchorPoint = Vector2.new(0.5, upFrame.AnchorPoint.Y)
	upFrame.Position = UDim2.new(0.5, 0, upPosition.Y.Scale, upPosition.Y.Offset)

	local icon = upFrame:FindFirstChild("Icon")
	if icon then
		local iconPosition = icon.Position
		icon.AnchorPoint = Vector2.new(0.5, icon.AnchorPoint.Y)
		icon.Position = UDim2.new(0.5, 0, iconPosition.Y.Scale, iconPosition.Y.Offset)
	else
		warn(("[CenterEnergyFrame] No HUD.Up.Icon found under %s -- only the outer frame was centered."):format(label))
	end

	print(("[CenterEnergyFrame] Centered HUD.Up%s horizontally under %s."):format(icon and " + Icon" or "", label))
end

local main = StarterGui:FindFirstChild("Main")
if main then
	centerUpFrame(main, "StarterGui.Main")
else
	warn("[CenterEnergyFrame] No StarterGui.Main found.")
end

for _, player in ipairs(Players:GetPlayers()) do
	local playerGui = player:FindFirstChild("PlayerGui")
	local liveMain = playerGui and playerGui:FindFirstChild("Main")
	if liveMain then
		centerUpFrame(liveMain, player.Name .. "'s live PlayerGui.Main")
	end
end
