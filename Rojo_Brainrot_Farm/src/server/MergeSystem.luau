-- MergeSystem.luau
-- Lives at ServerScriptService.Server.MergeSystem
-- Handles merging GameConfig.MergeRequirement copies of the same-tier brainrot into the next tier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local BrainrotSpawner = require(script.Parent.BrainrotSpawner)

local BrainrotModelsFolder = ServerStorage:WaitForChild("BrainrotModels")

local function mergeBrainrots(player: Player, ids: { string })
	local data = PlayerDataManager.Get(player)
	if not data then return false, "Data not loaded" end

	if #ids ~= GameConfig.MergeRequirement then
		return false, string.format("Need exactly %d brainrots to merge", GameConfig.MergeRequirement)
	end

	local matches = {}
	local sharedName = nil
	for _, entry in ipairs(data.OwnedBrainrots) do
		for _, id in ipairs(ids) do
			if entry.Id == id then
				if sharedName == nil then
					sharedName = entry.Name
				elseif sharedName ~= entry.Name then
					return false, "All brainrots must be the same tier to merge"
				end
				table.insert(matches, entry)
			end
		end
	end

	if #matches ~= #ids then
		return false, "One or more brainrots not found (already merged or sold?)"
	end

	local config = GameConfig.Brainrots[sharedName]
	if not config or not config.MergeInto then
		return false, "This brainrot is already max tier"
	end

	local plotsFolder = workspace:FindFirstChild("Plots")
	local plot = nil
	if plotsFolder then
		for _, p in ipairs(plotsFolder:GetChildren()) do
			if p:GetAttribute("OwnerUserId") == player.UserId then
				plot = p
				break
			end
		end
	end

	-- Brainrot models are parented directly to the physical slot they're sitting on (see
	-- BrainrotSpawner.buyBrainrot), so `child.Parent` here is the actual BrainrotSlots part —
	-- destroying the model automatically frees that slot for getNextSlot's live occupancy count.
	-- We also grab the old model's exact CFrame before destroying it so the merged result
	-- reappears in the same spot (same slot + stacked layer) instead of anywhere new.
	local freedSlot = nil
	local freedCFrame = nil
	for _, matchEntry in ipairs(matches) do
		for i, entry in ipairs(data.OwnedBrainrots) do
			if entry.Id == matchEntry.Id then
				table.remove(data.OwnedBrainrots, i)
				break
			end
		end

		if plot then
			for _, child in ipairs(plot:GetDescendants()) do
				if child:GetAttribute("BrainrotId") == matchEntry.Id then
					local slot = child.Parent
					if slot and slot:IsA("BasePart") then
						freedSlot = slot
						if child:IsA("Model") and child.PrimaryPart then
							freedCFrame = child:GetPrimaryPartCFrame()
						end
					end
					child:Destroy()
					break
				end
			end
		end
	end

	local newName = config.MergeInto
	local newId = HttpService:GenerateGUID(false)
	table.insert(data.OwnedBrainrots, { Name = newName, Id = newId })

	if plot and freedSlot then
		local template = BrainrotModelsFolder:FindFirstChild(newName)
		if template then
			local model = template:Clone()
			model:SetAttribute("BrainrotId", newId)
			model:SetAttribute("OwnerUserId", player.UserId)
			BrainrotSpawner.ColorModelByTier(model, newName)
			BrainrotSpawner.AnchorModel(model)
			if model.PrimaryPart and freedCFrame then
				model:SetPrimaryPartCFrame(freedCFrame)
			end
			model.Parent = freedSlot

			BrainrotSpawner.StartEnergyLoop(player, model, newName, plot)
		end
	end

	return true, newName
end

Remotes.MergeBrainrots.OnServerEvent:Connect(function(player, ids)
	if type(ids) ~= "table" then return end
	local success, resultOrError = mergeBrainrots(player, ids)
	Remotes.MergeBrainrots:FireClient(player, success, resultOrError)
end)

-- ===== Auto-merge platform: step on it to merge 3 owned copies of one tier into the next =====
-- Floating "Merge" text above the platform (the Part itself, built manually in Studio as
-- <plot>/MergePlatform). Created once per platform, safe to re-run on server start.
local function ensureMergeBillboard(platform: Instance)
	if platform:FindFirstChild("MergeBillboard") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MergeBillboard"
	billboard.Adornee = platform
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = platform

	local mergeLabel = Instance.new("TextLabel")
	mergeLabel.Name = "MergeLabel"
	mergeLabel.Size = UDim2.new(1, 0, 1, 0)
	mergeLabel.BackgroundTransparency = 1
	mergeLabel.Font = Enum.Font.GothamBold
	mergeLabel.TextScaled = true
	mergeLabel.TextColor3 = Color3.new(1, 1, 1)
	mergeLabel.Text = "Merge"
	mergeLabel.Parent = billboard
end

-- Finds up to `count` owned brainrot ids matching `brainrotName`, in insertion order.
local function findMatchingIds(data, brainrotName: string, count: number): { string }
	local ids = {}
	for _, entry in ipairs(data.OwnedBrainrots) do
		if entry.Name == brainrotName then
			table.insert(ids, entry.Id)
			if #ids >= count then break end
		end
	end
	return ids
end

-- MergePlatform's "MergeBrainrotName" attribute picks which tier it merges (defaults to the
-- tier-1 brainrot, since that's the one you asked for — set the attribute to make another
-- copy of this platform merge a different tier).
local function setupMergePlatform(plot: Instance)
	local platform = plot:FindFirstChild("MergePlatform")
	if not platform then return end

	ensureMergeBillboard(platform)

	local mergeBrainrotName = platform:GetAttribute("MergeBrainrotName") or "Tralalero"
	local onCooldown = {}

	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or onCooldown[player] then return end

		local data = PlayerDataManager.Get(player)
		if not data then return end

		local ids = findMatchingIds(data, mergeBrainrotName, GameConfig.MergeRequirement)
		if #ids < GameConfig.MergeRequirement then return end -- not enough yet, stay quiet

		onCooldown[player] = true

		local success, resultOrError = mergeBrainrots(player, ids)
		Remotes.MergeBrainrots:FireClient(player, success, resultOrError)
		if success then
			print(("[Merge] %s merged 3x %s into %s"):format(player.Name, mergeBrainrotName, tostring(resultOrError)))
		end

		task.delay(1, function()
			onCooldown[player] = nil
		end)
	end)
end

local function initAllMergePlatforms()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then
		warn("[MergeSystem] No workspace.Plots folder found — build your plots in Studio first.")
		return
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		setupMergePlatform(plot)
	end
end

initAllMergePlatforms()

return { MergeBrainrots = mergeBrainrots }
