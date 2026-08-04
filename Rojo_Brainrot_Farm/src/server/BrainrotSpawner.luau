-- BrainrotSpawner.luau
-- Lives at ServerScriptService.Server.BrainrotSpawner
-- Handles: buying a brainrot, placing it on the player's plot, and looping its energy drops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

-- NOTE: these ServerStorage folders are NOT managed by Rojo in this scaffold —
-- create them manually in Studio (right-click ServerStorage > Insert Object):
--   ServerStorage/BrainrotModels/<BrainrotName> (one Model per name in GameConfig.Brainrots)
--   ServerStorage/EnergyPart (a Part representing one unit of energy -- the fallback used by
--     any tier that doesn't have its own EnergyModels/Tier<N> below)
--   ServerStorage/EnergyModels/Tier<N> (OPTIONAL -- one Part per tier, e.g. "Tier1".."Tier15",
--     for a visually distinct energy drop per brainrot tier. See studio-tools/BuildTieredEnergyParts.luau.
--     Must be a Part, not a Model -- energy pickups use .CFrame/.Touched directly, same as EnergyPart.)
--   ServerStorage/StandPlatform (OPTIONAL -- a placeholder Part OR Model that spawns underneath
--     any brainrot in layer 2+ so it isn't floating mid-air. Falls back to a plain grey
--     generated block if you haven't built one yet -- swap it out any time for your own
--     platform, single Part or multi-part Model, either works.)
local BrainrotModelsFolder = ServerStorage:WaitForChild("BrainrotModels")
local EnergyPartTemplate = ServerStorage:WaitForChild("EnergyPart")
local EnergyModelsFolder = ServerStorage:FindFirstChild("EnergyModels")
local StandPlatformTemplate = ServerStorage:FindFirstChild("StandPlatform")

local function getEnergyTemplate(tier: number): Instance
	if EnergyModelsFolder then
		local tierTemplate = EnergyModelsFolder:FindFirstChild("Tier" .. tostring(tier))
		if tierTemplate then
			return tierTemplate
		end
	end
	return EnergyPartTemplate
end

-- Tints the energy pickup by tier (same GameConfig.TierColors used for brainrot placeholders),
-- so tiers are visually distinct even before you've built a dedicated EnergyModels/Tier<N>
-- for every tier -- e.g. tier 1 comes out as a plain yellow-ish bulb, tier 2 green, etc.
local function tintEnergyPart(energyPart: Instance, tier: number)
	local color = GameConfig.TierColors[tier]
	if not color then return end

	if energyPart:IsA("BasePart") then
		energyPart.Color = color
	end
	for _, descendant in ipairs(energyPart:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = color
		end
	end
end

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

-- Where each energy drop spawns relative to the brainrot that produced it: this many studs
-- out in front of it (along whichever way its model is actually facing) and this many studs
-- up. Tweak these two to taste once you see it against your model sizes.
local ENERGY_DROP_DISTANCE = 5
local ENERGY_DROP_HEIGHT = 2

-- How long an uncollected physical energy part sticks around in the world before auto-cleanup.
local ENERGY_PART_LIFETIME = 24

-- Occupancy is derived live from what's actually parented to the slot (each brainrot model
-- is parented directly to the slot it's sitting on), so there's no separate "Occupied" flag
-- to fall out of sync with reality.
local function countOccupants(slot: Instance): number
	local count = 0
	for _, child in ipairs(slot:GetChildren()) do
		if child:GetAttribute("BrainrotId") ~= nil then
			count += 1
		end
	end
	return count
end

-- Physical BrainrotSlots parts, ordered left-to-right (ascending world X) so "slot 1" is
-- always the same physical spot. Flip to .Z if your plot's row runs along that axis instead.
local function getSortedSlots(plot: Instance): { Instance }
	local slotsFolder = plot:FindFirstChild("BrainrotSlots")
	if not slotsFolder then return {} end

	local slots = slotsFolder:GetChildren()
	table.sort(slots, function(a, b)
		return a.Position.X < b.Position.X
	end)
	return slots
end

-- Returns the next open (slot, layer) pair. Fills layer 0 across every physical BrainrotSlots
-- part first, then starts stacking layer 1 above them once all base slots are full, and so on --
-- forms a 2D grid once a player owns more brainrots than there are physical slots for.
local function getNextSlot(plot: Instance): (Instance?, number?)
	local slots = getSortedSlots(plot)
	if #slots == 0 then return nil, nil end

	local maxLayers = math.ceil(GameConfig.MaxBrainrotsPerPlot / #slots)

	for layer = 0, maxLayers - 1 do
		for _, slot in ipairs(slots) do
			if countOccupants(slot) == layer then
				return slot, layer
			end
		end
	end

	return nil, nil
end

local function slotCFrame(slot: Instance, layer: number): CFrame
	return slot.CFrame + Vector3.new(0, layer * GameConfig.StackLayerHeight, 0)
end

-- The slot's own placement CFrame, further rotated by that brainrot's FacingOffset (if any)
-- so a model whose PrimaryPart doesn't match its visual front still ends up facing correctly.
local function brainrotSpawnCFrame(slot: Instance, layer: number, brainrotName: string): CFrame
	local config = GameConfig.Brainrots[brainrotName]
	local facingOffset = (config and config.FacingOffset) or 0
	return slotCFrame(slot, layer) * CFrame.Angles(0, math.rad(facingOffset), 0)
end

-- Fallback size/color for the generated placeholder stand platform, only used when
-- ServerStorage/StandPlatform doesn't exist yet.
local STAND_PLATFORM_THICKNESS = 1
local STAND_PLATFORM_COLOR = Color3.fromRGB(120, 120, 120)

-- Spawns a placeholder platform under a brainrot sitting at `layer` >= 1 (2nd row and up), so
-- it isn't floating mid-air -- parented as a CHILD of the brainrot model itself, so it gets
-- destroyed automatically whenever that model does (repack/merge), no separate cleanup needed.
-- Does nothing for layer 0, since those already sit directly on the physical BrainrotSlots part.
-- ServerStorage/StandPlatform can be either a single Part or a multi-part Model -- height and
-- positioning are handled generically for both via GetExtentsSize()/PivotTo() for Models.
local function addStandPlatform(model: Model, slot: Instance, layer: number)
	if layer <= 0 then return end

	local platform: Instance
	local height: number

	if StandPlatformTemplate then
		platform = StandPlatformTemplate:Clone()
		if platform:IsA("Model") then
			height = platform:GetExtentsSize().Y
			for _, part in ipairs(platform:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
		else
			local part = platform :: BasePart
			height = part.Size.Y
			part.Anchored = true
		end
	else
		local part = Instance.new("Part")
		part.Size = Vector3.new(slot.Size.X, STAND_PLATFORM_THICKNESS, slot.Size.Z)
		part.Material = Enum.Material.Plastic
		part.Color = STAND_PLATFORM_COLOR
		part.Anchored = true
		platform = part
		height = STAND_PLATFORM_THICKNESS
	end

	platform.Name = "StandPlatform"

	-- Sits right under wherever the brainrot's feet are, whatever the platform's own height is.
	local targetCFrame = slotCFrame(slot, layer) * CFrame.new(0, -height / 2, 0)
	if platform:IsA("Model") then
		platform:PivotTo(targetCFrame)
	else
		(platform :: BasePart).CFrame = targetCFrame
	end

	platform.Parent = model
end

-- Stacked brainrots sit mid-air above other slots once layer > 0, so they need to be
-- anchored or they'd just fall through/off the slot below them. Also non-collidable so
-- players (and other brainrots/energy drops) can't bump into or get stuck on them.
local function anchorModel(model: Model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
end

-- Small floating "Name / Tier N" text above a spawned brainrot placeholder.
local function addNameplate(model: Model, brainrotName: string)
	local config = GameConfig.Brainrots[brainrotName]
	if not config or not model.PrimaryPart then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nameplate"
	billboard.Adornee = model.PrimaryPart
	billboard.Size = UDim2.new(0, 110, 0, 32)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = model.PrimaryPart

	local label = Instance.new("TextLabel")
	label.Name = "NameplateLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = string.format("%s\nTier %d", brainrotName, config.Tier)
	label.Parent = billboard
end

local DROP_INTERVAL_JITTER = 0.2 -- +/- this fraction of DropInterval, randomized each drop, so identical brainrots don't all drop energy in lockstep

local function startEnergyLoop(player: Player, brainrotModel: Model, brainrotName: string, plot: Instance)
	local config = GameConfig.Brainrots[brainrotName]
	if not config then return end

	task.spawn(function()
		while brainrotModel.Parent and player.Parent do
			local jitter = 1 + (math.random() * 2 - 1) * DROP_INTERVAL_JITTER
			task.wait(config.DropInterval * jitter)

			local primaryPart = brainrotModel.PrimaryPart
			if not primaryPart then continue end

			-- The hop itself is played client-side (see init.client.luau) -- Roblox throttles
			-- CFrame replication for Anchored parts much harder than physics-simulated ones, so
			-- animating it here on the server and letting it replicate reads as choppy no matter
			-- how smoothly it's computed. This just tells every client "hop this model" and each
			-- one animates its own already-replicated copy locally, with no per-frame network cost.
			Remotes.BrainrotHop:FireAllClients(brainrotModel)

			local energyTemplate = getEnergyTemplate(config.Tier)
			local energyPart = energyTemplate:Clone()
			tintEnergyPart(energyPart, config.Tier)
			energyPart:SetAttribute("EnergyValue", config.EnergyPerDrop)
			energyPart:SetAttribute("OwnerUserId", player.UserId)

			-- Real physics: it actually falls under gravity and collides with the world
			-- (your conveyor belt included), instead of being teleported along a scripted path.
			-- Forced every spawn regardless of how the template itself was authored in Studio.
			energyPart.Anchored = false
			energyPart.CanCollide = true
			if energyPart:IsA("Part") then
				energyPart.Shape = Enum.PartType.Block
			end
			-- Local -Z is "forward" in Roblox's CFrame convention, so this multiplication spawns
			-- it ENERGY_DROP_DISTANCE studs out in front of the brainrot (rotated correctly with
			-- however the model is actually facing) and ENERGY_DROP_HEIGHT studs up.
			energyPart.CFrame = primaryPart.CFrame * CFrame.new(0, ENERGY_DROP_HEIGHT, -ENERGY_DROP_DISTANCE)
			energyPart.Parent = workspace

			-- Unanchored parts default to Roblox's AUTOMATIC network ownership, which hands
			-- physics simulation of a part to whichever player is nearest it -- meaning the
			-- conveyor ride for this specific part can end up depending on that one player's
			-- connection quality. Forcing server ownership (nil) makes the server itself
			-- simulate it instead, so it keeps moving smoothly on the belt even if a nearby
			-- player's connection gets shaky, right up until they actually disconnect.
			energyPart:SetNetworkOwner(nil)

			-- Player must physically walk into the energy part to collect it.
			-- Only the owner of the brainrot that produced it can collect it (no stealing, for now).
			local collected = false
			local touchConnection
			touchConnection = energyPart.Touched:Connect(function(hit)
				if collected then return end

				local character = hit.Parent
				local touchingPlayer = Players:GetPlayerFromCharacter(character)
				if not touchingPlayer or touchingPlayer.UserId ~= player.UserId then return end

				collected = true
				local data = PlayerDataManager.Get(touchingPlayer)
				if data then
					data.StoredEnergy += config.EnergyPerDrop
					Remotes.StatsUpdate:FireClient(touchingPlayer, { StoredEnergy = data.StoredEnergy })
				end

				if touchConnection then touchConnection:Disconnect() end
				energyPart:Destroy()
			end)

			-- No more scripted CFrame tweening down a conveyor -- your real conveyor belt will
			-- move it via actual physics once it's built. This is just a cleanup timer so an
			-- uncollected drop doesn't sit in the world forever.
			task.delay(ENERGY_PART_LIFETIME, function()
				if touchConnection then touchConnection:Disconnect() end
				if energyPart.Parent and not collected then
					energyPart:Destroy()
				end
			end)
		end
	end)
end

-- A bulk buy (e.g. the shop's 100x platforms) is meant to immediately cascade-merge afterward
-- (see ShopPrompts.buyAt / MergeSystem.AutoMergeAll), so checking the raw incoming quantity
-- against MaxBrainrotsPerPlot rejects purchases that would actually fit just fine once the
-- guaranteed merges happen. This simulates the merge cascade on plain tier counts (not real
-- IDs) to project the ACTUAL final resting count, so buying 100 of a low tier isn't blocked
-- just because 100 don't fit on the grid before merging -- only a genuinely-too-large final
-- count (e.g. buying huge amounts of an already-max-tier brainrot, which can't merge further)
-- still gets rejected.
local function simulateFinalCountAfterMerges(data, addName: string, addQuantity: number): number
	local counts = {}
	for _, entry in ipairs(data.OwnedBrainrots) do
		counts[entry.Name] = (counts[entry.Name] or 0) + 1
	end
	counts[addName] = (counts[addName] or 0) + addQuantity

	for _, tierName in ipairs(GameConfig.BrainrotOrder) do
		local tierConfig = GameConfig.Brainrots[tierName]
		local owned = counts[tierName] or 0
		if tierConfig and tierConfig.MergeInto and owned >= GameConfig.MergeRequirement then
			local groups = math.floor(owned / GameConfig.MergeRequirement)
			counts[tierName] = owned - groups * GameConfig.MergeRequirement
			counts[tierConfig.MergeInto] = (counts[tierConfig.MergeInto] or 0) + groups
		end
	end

	local total = 0
	for _, count in pairs(counts) do
		total += count
	end
	return total
end

-- `skipPhysicalSpawn`: when true, only updates data.OwnedBrainrots -- no clone/anchor/stand
-- platform/nameplate/energy-loop per unit. Meant for bulk buys the caller is about to
-- immediately auto-merge (see ShopPrompts.buyAt): RepackPlot wipes and rebuilds the whole plot
-- from data moments later regardless, so physically spawning e.g. 100 individual models (each
-- with its own StandPlatform, nameplate, and a persistent startEnergyLoop coroutine) just to
-- have RepackPlot immediately destroy them all is pure wasted work -- and since that waste
-- repeats every single repeat-touch trigger, it's what was actually causing the lag/inconsistency
-- on the 100x platforms specifically (including a pileup of short-lived energy-loop coroutines
-- that don't exit until their now-destroyed model's Parent goes nil on their own next wait cycle).
local function buyBrainrot(player: Player, brainrotName: string, quantity: number?, skipPhysicalSpawn: boolean?)
	quantity = quantity or 1

	local config = GameConfig.Brainrots[brainrotName]
	if not config then return false, "Invalid brainrot" end

	local data = PlayerDataManager.Get(player)
	if not data then return false, "Data not loaded" end

	local totalPrice = config.Price * quantity
	if data.Cash < totalPrice then
		return false, "Not enough cash"
	end

	local plot = getPlayerPlot(player)
	if not plot then return false, "No plot assigned" end

	if simulateFinalCountAfterMerges(data, brainrotName, quantity) > GameConfig.MaxBrainrotsPerPlot then
		return false, "Not enough room on plot"
	end

	-- Cheap up-front feasibility check (also catches a missing/empty BrainrotSlots folder)
	-- before we touch coins or data. The real per-unit lookup happens in the loop below, since
	-- occupancy changes as each model gets parented -- skipped entirely when skipPhysicalSpawn
	-- is set, since nothing physical gets parented onto a slot in that case at all (the caller's
	-- immediate RepackPlot lays everything out from data instead, uncapped by physical slots).
	if not skipPhysicalSpawn and not getNextSlot(plot) then
		return false, "No free slot on plot"
	end

	data.Cash -= totalPrice

	local template = BrainrotModelsFolder:FindFirstChild(brainrotName)
	if not template then
		warn(("[BrainrotSpawner] No ServerStorage/BrainrotModels/%s found -- %s will be tracked in data but won't visually spawn, and its slot will look free to future purchases/merges"):format(brainrotName, brainrotName))
	end

	for _ = 1, quantity do
		local brainrotId = HttpService:GenerateGUID(false)
		table.insert(data.OwnedBrainrots, { Name = brainrotName, Id = brainrotId })

		if template and not skipPhysicalSpawn then
			local slot, layer = getNextSlot(plot)
			if slot then
				local model = template:Clone()
				model:SetAttribute("BrainrotId", brainrotId)
				model:SetAttribute("OwnerUserId", player.UserId)
				anchorModel(model)
				if model.PrimaryPart then
					model:SetPrimaryPartCFrame(brainrotSpawnCFrame(slot, layer :: number, brainrotName))
				end
				model.Parent = slot
				addStandPlatform(model, slot, layer :: number)
				addNameplate(model, brainrotName)

				startEnergyLoop(player, model, brainrotName, plot)
			end
		end
	end

	return true, data.Cash
end

-- Wipes every brainrot model currently on `plot` and rebuilds them from `data.OwnedBrainrots`
-- with no gaps: highest tier first, filling the bottom row (layer 0) left-to-right before
-- stacking a layer above it. Called after every merge so the plot never keeps stale holes
-- where the merged-away brainrots used to sit.
local function repackPlot(player: Player, plot: Instance, data)
	local slots = getSortedSlots(plot)
	if #slots == 0 then return end

	-- Destroying each old model stops its energy loop next iteration (the loop's while
	-- condition checks brainrotModel.Parent, which Destroy() clears).
	for _, slot in ipairs(slots) do
		for _, child in ipairs(slot:GetChildren()) do
			if child:GetAttribute("BrainrotId") ~= nil then
				child:Destroy()
			end
		end
	end

	local sortedEntries = {}
	for _, entry in ipairs(data.OwnedBrainrots) do
		table.insert(sortedEntries, entry)
	end
	table.sort(sortedEntries, function(a, b)
		local tierA = GameConfig.Brainrots[a.Name] and GameConfig.Brainrots[a.Name].Tier or 0
		local tierB = GameConfig.Brainrots[b.Name] and GameConfig.Brainrots[b.Name].Tier or 0
		return tierA > tierB
	end)

	local warnedMissing = {}
	local numSlots = #slots
	for index, entry in ipairs(sortedEntries) do
		local template = BrainrotModelsFolder:FindFirstChild(entry.Name)
		if not template and not warnedMissing[entry.Name] then
			warnedMissing[entry.Name] = true
			warn(("[BrainrotSpawner] No ServerStorage/BrainrotModels/%s found -- it won't visually spawn during repack, and its slot will look free to future purchases/merges"):format(entry.Name))
		end

		if template then
			local slot = slots[((index - 1) % numSlots) + 1]
			local layer = math.floor((index - 1) / numSlots)

			local model = template:Clone()
			model:SetAttribute("BrainrotId", entry.Id)
			model:SetAttribute("OwnerUserId", player.UserId)
			anchorModel(model)
			if model.PrimaryPart then
				model:SetPrimaryPartCFrame(brainrotSpawnCFrame(slot, layer, entry.Name))
			end
			model.Parent = slot
			addStandPlatform(model, slot, layer)
			addNameplate(model, entry.Name)

			startEnergyLoop(player, model, entry.Name, plot)
		end
	end
end

Remotes.BuyBrainrot.OnServerEvent:Connect(function(player, brainrotName, quantity)
	local success, resultOrError = buyBrainrot(player, brainrotName, quantity)
	Remotes.BuyBrainrot:FireClient(player, success, resultOrError)
end)

return {
	StartEnergyLoop = startEnergyLoop,
	BuyBrainrot = buyBrainrot,
	AnchorModel = anchorModel,
	RepackPlot = repackPlot,
}
