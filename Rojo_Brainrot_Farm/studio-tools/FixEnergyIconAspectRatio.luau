-- FixEnergyIconAspectRatio.luau
-- NOT synced by Rojo -- one-time Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- The Energy HUD icon (Main.HUD.Up.Icon) stretches when the window is resized because its
-- Size is scale-based and nothing is pinning its width:height ratio -- as the viewport's aspect
-- ratio changes, the icon's absolute pixel box stops being square/whatever ratio the source
-- image actually is, so the ImageLabel just stretches the image to fill whatever box it ends up
-- with. A UIAspectRatioConstraint locks that ratio so it scales down/up uniformly instead.
--
-- This copies whatever AspectRatio the Cash icon (Main.HUD.Left.Icon) already uses if it has a
-- UIAspectRatioConstraint (since that one was already fixed by hand), so both icons match --
-- otherwise it falls back to 1 (square), the common case for these badge-style HUD icons.
--
-- Safe to re-run: it only creates the constraint if one doesn't already exist, and just updates
-- the AspectRatio value if one does.

local player = game:GetService("Players").LocalPlayer
local playerGui = player and player:FindFirstChild("PlayerGui")
if not playerGui then
	warn("[FixEnergyIconAspectRatio] No PlayerGui found -- run this while in Play mode (Play Solo / Start), not Edit mode.")
	return
end

local main = playerGui:FindFirstChild("Main")
if not main then
	warn("[FixEnergyIconAspectRatio] No Main ScreenGui found under PlayerGui.")
	return
end

local hud = main:FindFirstChild("HUD")
if not hud then
	warn("[FixEnergyIconAspectRatio] No HUD found under Main.")
	return
end

local upFrame = hud:FindFirstChild("Up")
local energyIcon = upFrame and upFrame:FindFirstChild("Icon")
if not energyIcon then
	warn("[FixEnergyIconAspectRatio] No Main.HUD.Up.Icon found.")
	return
end

local aspectRatio = 1
local leftFrame = hud:FindFirstChild("Left")
local cashIcon = leftFrame and leftFrame:FindFirstChild("Icon")
local cashConstraint = cashIcon and cashIcon:FindFirstChildWhichIsA("UIAspectRatioConstraint")
if cashConstraint then
	aspectRatio = cashConstraint.AspectRatio
end

local energyConstraint = energyIcon:FindFirstChildWhichIsA("UIAspectRatioConstraint")
if not energyConstraint then
	energyConstraint = Instance.new("UIAspectRatioConstraint")
	energyConstraint.Parent = energyIcon
end
energyConstraint.AspectRatio = aspectRatio
energyConstraint.DominantAxis = Enum.DominantAxis.Width

print(("[FixEnergyIconAspectRatio] Set Main.HUD.Up.Icon's UIAspectRatioConstraint.AspectRatio to %.3f"):format(aspectRatio))
