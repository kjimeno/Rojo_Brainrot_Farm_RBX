-- BuildStudMaterialTestPart.luau
-- NOT synced by Rojo (not referenced in default.project.json) — this is a one-time
-- Studio Command Bar script, not part of the running game.
--
-- Paste this whole file into Studio's View > Command Bar and press Enter once.
--
-- There's no Material literally named "Stud" -- the classic bumpy/studded plastic look
-- (the one your Collector/ConveyorStart parts almost certainly have) comes from the
-- `Plastic` material rendered under Roblox's LEGACY (pre-2022) material system.
--
-- The global toggle for that (MaterialService.Use2022Materials) is NOT scriptable -- Roblox
-- blocks writing it from Command Bar/scripts even though older docs suggested you could. You
-- have to flip it by hand in Studio instead: Window > 3D > Material to open the Material
-- Manager, then turn off "Use 2022 Materials" there.
--
-- This script just drops a small test Part with Material = Plastic near the origin so you can
-- see how it looks once you've toggled that setting off.

local Workspace = game:GetService("Workspace")

local part = Instance.new("Part")
part.Name = "StudMaterialTest"
part.Size = Vector3.new(4, 1, 4)
part.Anchored = true
part.Material = Enum.Material.Plastic
part.Color = Color3.fromRGB(163, 162, 165) -- classic baseplate grey, change to whatever you like
part.Position = Vector3.new(0, 5, 0)
part.Parent = Workspace

print("[BuildStudMaterialTestPart] Added a test Plastic part at (0, 5, 0). Toggle off 'Use 2022 Materials' in Window > 3D > Material to see the classic studded look.")
