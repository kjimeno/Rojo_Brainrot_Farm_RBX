-- RepeatingTouch.luau
-- Lives at ServerScriptService.Server.RepeatingTouch
-- Shared "keep re-triggering while the player stands on this platform" behavior, used by every
-- Touched-based platform in the game (shop stalls, deposit area, coin vault, upgrade platform,
-- merge platform) instead of each one reimplementing its own debounce/repeat loop.

local Players = game:GetService("Players")

local REPEAT_DEBOUNCE = 0.5 -- seconds between every repeat, for as long as they keep standing there

-- Runs `action(player)` immediately when `player` touches `platform`, then keeps re-running it
-- every REPEAT_DEBOUNCE seconds for as long as they're still touching it. Only one repeat loop
-- runs per player per platform at a time; stepping off and back on restarts it.
--
-- Touched/TouchEnded fire per BODY PART, not per player -- a standing character has several
-- parts (arms, legs, torso) that can individually flicker on/off contact from idle animation
-- alone, even while the player hasn't actually moved. A per-player touch COUNT (rather than a
-- single true/false flag) is what makes this robust to that: the loop only actually stops once
-- every part has left, so one limb's brief TouchEnded doesn't reset the whole debounce and let
-- the next part's Touched sneak in an instant, un-debounced call.
local function setupRepeatingTouch(platform: BasePart, action: (Player) -> ())
	local touchCounts = {} -- [player] = number of this player's body parts currently touching

	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		touchCounts[player] = (touchCounts[player] or 0) + 1
		if touchCounts[player] > 1 then return end -- loop already running for this player

		task.spawn(function()
			while (touchCounts[player] or 0) > 0 do
				action(player)
				task.wait(REPEAT_DEBOUNCE)
			end
		end)
	end)

	platform.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or not touchCounts[player] then return end

		touchCounts[player] = math.max(touchCounts[player] - 1, 0)
	end)
end

return setupRepeatingTouch
