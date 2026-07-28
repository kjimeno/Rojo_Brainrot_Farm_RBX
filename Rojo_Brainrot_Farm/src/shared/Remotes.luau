-- Remotes.luau
-- Lives at ReplicatedStorage.Shared.Remotes (accessible from client AND server)
-- Server creates the RemoteEvents on first require; client just waits for them.
-- This means you never have to hand-add RemoteEvent instances in Studio or project.json.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"BuyBrainrot",
	"MergeBrainrots",
	"UpgradeConversion",
	"StatsUpdate",
	"RequestStats",
	"BrainrotHop",
	"PlatformPress",
	"ShopSpaceError",
	"MoneyError",
}

local Remotes = {}

local remotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")

if RunService:IsServer() then
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "RemoteEvents"
		remotesFolder.Parent = ReplicatedStorage
	end

	for _, name in ipairs(REMOTE_NAMES) do
		if not remotesFolder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotesFolder
		end
	end
else
	remotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
	for _, name in ipairs(REMOTE_NAMES) do
		remotesFolder:WaitForChild(name)
	end
end

for _, name in ipairs(REMOTE_NAMES) do
	Remotes[name] = remotesFolder:WaitForChild(name)
end

return Remotes
