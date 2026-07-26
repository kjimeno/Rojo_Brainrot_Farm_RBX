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

local READY_COLOR = Color3.fromRGB(235, 219, 0)
local NOT_READY_COLOR = Color3.fromRGB(163, 162, 165)

-- Optional: ServerStorage/"Particle effects"/HitEffect (from the purchased UI/VFX kit) -- a
-- one-shot particle burst rig, kept as a template in ServerStorage (server-only, never
-- replicates, never visible until cloned) same as BrainrotModels/EnergyPart/StandPlatform.
-- If it's not there, merges just skip the effect silently.
local HIT_EFFECT_BURST_COUNT = 1
local particleEffectsFolder = ServerStorage:FindFirstChild("Particle effects")
local hitEffectTemplate = particleEffectsFolder and particleEffectsFolder:FindFirstChild("HitEffect")

-- Creates ONE permanent copy of HitEffect at `platform`, safe to call every server start
-- without duplicating it. Cloning it once here (rather than per-merge) means it's already
-- replicated to every client long before anyone ever merges -- calling :Emit() on a
-- brand-new same-frame Clone() can visibly lag or get dropped while the client is still
-- catching up on the new instance existing at all, so this avoids that delay entirely.
local function ensureHitEffect(platform: Instance)
	if not hitEffectTemplate then return end
	if platform:FindFirstChild("HitEffect") then return end

	local effect = hitEffectTemplate:Clone()
	effect.CFrame = platform.CFrame

	-- This now sits permanently in the workspace (not tucked away in ServerStorage), so make
	-- sure it's not left continuously emitting -- :Emit() below still bursts fine regardless
	-- of Enabled, this just stops it from idly looping forever at the platform.
	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end

	effect.Parent = platform
end

-- Fires every ParticleEmitter under `platform`'s (already-existing, already-replicated)
-- HitEffect once -- a "burst" rather than continuous emission.
local function playMergeEffect(plot: Instance)
	local platform = plot:FindFirstChild("MergePlatform")
	if not platform then return end

	local effect = platform:FindFirstChild("HitEffect")
	if not effect then return end

	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant:Emit(HIT_EFFECT_BURST_COUNT)
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

-- Pure data-only merge: validates `ids`, removes them from `data.OwnedBrainrots`, and adds
-- the resulting next-tier entry. Does NOT touch the plot's visuals -- callers that want to
-- do several merges back-to-back (see setupMergePlatform below) repack the plot once at the
-- end instead of once per merge, so it doesn't destroy/reclone every model on the plot
-- repeatedly for one big multi-merge.
local function mergeIds(data, ids: { string }): (boolean, string)
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

	for _, matchEntry in ipairs(matches) do
		for i, entry in ipairs(data.OwnedBrainrots) do
			if entry.Id == matchEntry.Id then
				table.remove(data.OwnedBrainrots, i)
				break
			end
		end
	end

	local newName = config.MergeInto
	local newId = HttpService:GenerateGUID(false)
	table.insert(data.OwnedBrainrots, { Name = newName, Id = newId })

	return true, newName
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

-- True if the player has enough copies of ANY tier to merge right now.
local function canMergeAnything(data): boolean
	for _, brainrotName in ipairs(GameConfig.BrainrotOrder) do
		if #findMatchingIds(data, brainrotName, GameConfig.MergeRequirement) >= GameConfig.MergeRequirement then
			return true
		end
	end
	return false
end

-- Colors the MergePlatform yellow + shows its "Merge" text when the plot owner has enough of
-- some tier to merge, grey + hidden otherwise. Call this any time data.OwnedBrainrots changes
-- for that plot's owner (buying, merging) so the indicator stays live -- not just on touch.
local function updateMergePlatformState(plot: Instance, data)
	local platform = plot:FindFirstChild("MergePlatform")
	if not platform then return end

	local ready = canMergeAnything(data)
	platform.Color = ready and READY_COLOR or NOT_READY_COLOR

	local billboard = platform:FindFirstChild("MergeBillboard")
	if billboard then
		billboard.Enabled = ready
	end
end

local function mergeBrainrots(player: Player, ids: { string })
	local data = PlayerDataManager.Get(player)
	if not data then return false, "Data not loaded" end

	local success, resultOrError = mergeIds(data, ids)
	if not success then return false, resultOrError end

	local plot = getPlayerPlot(player)
	if plot then
		-- Burst fires first so it's instant -- RepackPlot below rebuilds every brainrot model
		-- on the whole plot (not just the merged ones), which can take a noticeable moment
		-- with a large inventory, and shouldn't delay the visual feedback.
		playMergeEffect(plot)

		-- Full repack rather than just reusing the one freed slot: merging removes 3 brainrots
		-- from potentially 3 different spots, so only patching the last one would leave holes
		-- wherever the other two used to sit. RepackPlot wipes and rebuilds the whole layout
		-- from data.OwnedBrainrots, highest tier first, with no gaps in the bottom row.
		BrainrotSpawner.RepackPlot(player, plot, data)
		updateMergePlatformState(plot, data)
	end

	return true, resultOrError
end

Remotes.MergeBrainrots.OnServerEvent:Connect(function(player, ids)
	if type(ids) ~= "table" then return end
	local success, resultOrError = mergeBrainrots(player, ids)
	Remotes.MergeBrainrots:FireClient(player, success, resultOrError)
end)

-- ===== Auto-merge platform: step on it to merge 3 owned copies of one tier into the next =====
-- Floating "Merge" text above the platform (the Part itself, built manually in Studio as
-- <plot>/MergePlatform). Created once per platform, safe to re-run on server start. Starts
-- disabled (invisible) -- updateMergePlatformState above turns it on/off based on readiness.
local function ensureMergeBillboard(platform: Instance)
	if platform:FindFirstChild("MergeBillboard") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "MergeBillboard"
	billboard.Adornee = platform
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
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

-- Merges every complete group of GameConfig.MergeRequirement, at EVERY tier, cascading all
-- the way up to tier 5 in one call. GameConfig.BrainrotOrder lists tiers low-to-high, and this
-- drains a tier's triples into the next tier before moving on to process that next tier --
-- so 9 owned Tralalero (tier 1) becomes 3 TrippiTroppi (tier 2) becomes 1 BombardiroCrocodilo
-- (tier 3), all within this single pass, since each tier's newly-created entries are already
-- in data.OwnedBrainrots by the time we get to processing that tier.
local function mergeAllPossible(data): number
	local mergeCount = 0
	for _, brainrotName in ipairs(GameConfig.BrainrotOrder) do
		while true do
			local ids = findMatchingIds(data, brainrotName, GameConfig.MergeRequirement)
			if #ids < GameConfig.MergeRequirement then break end

			local success, resultOrError = mergeIds(data, ids)
			if not success then
				warn(("[Merge] merge stopped early for %s: %s"):format(brainrotName, tostring(resultOrError)))
				break
			end
			mergeCount += 1
		end
	end
	return mergeCount
end

local function setupMergePlatform(plot: Instance)
	local platform = plot:FindFirstChild("MergePlatform")
	if not platform then return end

	ensureMergeBillboard(platform)
	ensureHitEffect(platform)
	platform.Color = NOT_READY_COLOR

	local onCooldown = {}

	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or onCooldown[player] then return end

		local data = PlayerDataManager.Get(player)
		if not data then return end

		local mergeCount = mergeAllPossible(data)
		if mergeCount == 0 then return end -- nothing mergeable at any tier, stay quiet

		onCooldown[player] = true

		-- Re-looked-up rather than reusing the outer `plot` param: this platform's Touched
		-- fires for whichever player steps on it, so this always repacks the TOUCHING
		-- player's own plot, even if they're standing on someone else's platform.
		local ownerPlot = getPlayerPlot(player)
		if ownerPlot then
			-- Burst fires first so it's instant -- RepackPlot below rebuilds every brainrot
			-- model on the whole plot, which can take a noticeable moment with a large
			-- inventory, and shouldn't delay the visual feedback.
			playMergeEffect(ownerPlot)
			BrainrotSpawner.RepackPlot(player, ownerPlot, data)
			updateMergePlatformState(ownerPlot, data)
		end
		Remotes.MergeBrainrots:FireClient(player, true, mergeCount)
		print(("[Merge] %s merged %d group(s) across all tiers"):format(player.Name, mergeCount))

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

return {
	MergeBrainrots = mergeBrainrots,
	UpdateMergePlatform = updateMergePlatformState,
}
