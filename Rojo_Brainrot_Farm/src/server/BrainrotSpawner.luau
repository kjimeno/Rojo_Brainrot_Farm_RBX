-- BrainrotSpawner.luau
-- Lives at ServerScriptService.Server.BrainrotSpawner
-- Handles: buying a brainrot, placing it on the player's plot, and looping its energy drops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

-- NOTE: these ServerStorage folders are NOT managed by Rojo in this scaffold —
-- create them manually in Studio (right-click ServerStorage > Insert Object):
--   ServerStorage/BrainrotModels/<BrainrotName> (one Model per name in GameConfig.Brainrots)
--   ServerStorage/EnergyPart (a Part/Model representing one unit of energy)
local BrainrotModelsFolder = ServerStorage:WaitForChild("BrainrotModels")
local EnergyPartTemplate = ServerStorage:WaitForChild("EnergyPart")

local function getPlayerPlot(player: Player)
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function getNextSlot(plot: Instance)
	local slotsFolder = plot:FindFirstChild("BrainrotSlots")
	if not slotsFolder then return nil end
	for _, slot in ipairs(slotsFolder:GetChildren()) do
		if slot:GetAttribute("Occupied") ~= true then
			return slot
		end
	end
	return nil
end

local function startEnergyLoop(player: Player, brainrotModel: Model, brainrotName: string, plot: Instance)
	local config = GameConfig.Brainrots[brainrotName]
	if not config then return end

	task.spawn(function()
		while brainrotModel.Parent and player.Parent do
			task.wait(config.DropInterval)

			local conveyorStart = plot:FindFirstChild("ConveyorStart")
			if not conveyorStart then continue end

			local energyPart = EnergyPartTemplate:Clone()
			energyPart:SetAttribute("EnergyValue", config.EnergyPerDrop)
			energyPart:SetAttribute("OwnerUserId", player.UserId)
			energyPart.CFrame = conveyorStart.CFrame + Vector3.new(0, 2, 0)
			energyPart.Parent = workspace

			local conveyorEnd = plot:FindFirstChild("ConveyorEnd")
			if conveyorEnd then
				local tween = TweenService:Create(
					energyPart,
					TweenInfo.new(GameConfig.ConveyorTravelTime, Enum.EasingStyle.Linear),
					{ CFrame = conveyorEnd.CFrame + Vector3.new(0, 2, 0) }
				)
				tween:Play()
			end
		end
	end)
end

local function buyBrainrot(player: Player, brainrotName: string)
	local config = GameConfig.Brainrots[brainrotName]
	if not config then return false, "Invalid brainrot" end

	local data = PlayerDataManager.Get(player)
	if not data then return false, "Data not loaded" end

	if data.Coins < config.Price then
		return false, "Not enough coins"
	end

	local plot = getPlayerPlot(player)
	if not plot then return false, "No plot assigned" end

	if #data.OwnedBrainrots >= GameConfig.MaxBrainrotsPerPlot then
		return false, "Plot is full"
	end

	local slot = getNextSlot(plot)
	if not slot then return false, "No free slot on plot" end

	data.Coins -= config.Price
	local brainrotId = HttpService:GenerateGUID(false)
	table.insert(data.OwnedBrainrots, { Name = brainrotName, Id = brainrotId })

	local template = BrainrotModelsFolder:FindFirstChild(brainrotName)
	if template then
		local model = template:Clone()
		model:SetAttribute("BrainrotId", brainrotId)
		model:SetAttribute("OwnerUserId", player.UserId)
		if model.PrimaryPart then
			model:SetPrimaryPartCFrame(slot.CFrame)
		end
		model.Parent = plot
		slot:SetAttribute("Occupied", true)

		startEnergyLoop(player, model, brainrotName, plot)
	end

	return true, data.Coins
end

Remotes.BuyBrainrot.OnServerEvent:Connect(function(player, brainrotName)
	local success, resultOrError = buyBrainrot(player, brainrotName)
	Remotes.BuyBrainrot:FireClient(player, success, resultOrError)
end)

return {
	StartEnergyLoop = startEnergyLoop,
	BuyBrainrot = buyBrainrot,
}
