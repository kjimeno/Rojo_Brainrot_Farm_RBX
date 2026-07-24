-- ShopPrompts.luau
-- Lives at ServerScriptService.Server.ShopPrompts
-- Listens for ANY ProximityPrompt in the game that has a "BrainrotName" attribute set,
-- and treats triggering it as "buy this brainrot for this player."
-- This lets you build a shop stall entirely with placeholder Parts + ProximityPrompts —
-- no client UI or RemoteEvent wiring needed to test the buy flow.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BrainrotSpawner = require(script.Parent.BrainrotSpawner)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	local brainrotName = prompt:GetAttribute("BrainrotName")
	if not brainrotName then return end -- not a shop prompt, ignore it

	local success, resultOrError = BrainrotSpawner.BuyBrainrot(player, brainrotName)

	if success then
		local data = PlayerDataManager.Get(player)
		Remotes.StatsUpdate:FireClient(player, { Coins = data.Coins })
		print(("[Shop] %s bought a %s. Coins left: %d"):format(player.Name, brainrotName, data.Coins))
	else
		print(("[Shop] %s failed to buy %s: %s"):format(player.Name, brainrotName, tostring(resultOrError)))
		-- Once you build real UI, fire a dedicated remote here to show an error toast/sound.
	end
end)

return true
