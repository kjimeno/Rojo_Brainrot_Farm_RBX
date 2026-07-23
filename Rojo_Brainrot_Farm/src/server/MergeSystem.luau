-- MergeSystem.luau
-- Lives at ServerScriptService.Server.MergeSystem
-- Handles merging GameConfig.MergeRequirement copies of the same-tier brainrot into the next tier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

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

	local freedSlot = nil
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
						slot:SetAttribute("Occupied", false)
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
			if model.PrimaryPart then
				model:SetPrimaryPartCFrame(freedSlot.CFrame)
			end
			model.Parent = plot
			freedSlot:SetAttribute("Occupied", true)

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

return { MergeBrainrots = mergeBrainrots }
