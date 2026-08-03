-- RepeatingTouch.luau
-- Lives at ServerScriptService.Server.RepeatingTouch
-- Shared "keep re-triggering while the player stands on this platform" behavior, used by every
-- Touched-based platform in the game (shop stalls, deposit area, coin vault, upgrade platform,
-- merge platform) instead of each one reimplementing its own debounce/repeat loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RepeatingTouch = {}

RepeatingTouch.DEFAULT_DEBOUNCE = 1.0 -- seconds between every repeat, for as long as they keep standing there

-- Runs `action(player)` immediately when `player` touches `platform`, then keeps re-running it
-- for as long as they're still touching it. Only one repeat loop runs per player per platform at
-- a time; stepping off and back on restarts it.
--
-- `debounceSchedule` is optional: a function (triggerCount: number) -> number, called after each
-- trigger with how many times `action` has fired so far (1 for the very first), returning how
-- long to wait before the next one. Defaults to a flat RepeatingTouch.DEFAULT_DEBOUNCE gap every
-- time if omitted -- pass your own e.g. to keep the first couple of triggers slower before
-- speeding up.
--
-- Touched/TouchEnded fire per BODY PART, not per player -- a standing character has several
-- parts (arms, legs, torso) that can individually flicker on/off contact from idle animation
-- alone, even while the player hasn't actually moved. A per-player touch COUNT (rather than a
-- single true/false flag) is what makes this robust to that: the loop only actually stops once
-- every part has left, so one limb's brief TouchEnded doesn't reset the whole debounce and let
-- the next part's Touched sneak in an instant, un-debounced call.
--
-- touchCount alone isn't enough, though: the loop only re-checks the count once per debounce
-- cycle (inside its task.wait), so if a player fully leaves and re-touches fast enough, the
-- count can bounce 1 -> 0 -> 1 in between two checks. The OLD loop never saw it hit 0, so it
-- never exited -- but Touched saw the count go from 0 back to 1 and (wrongly) started a SECOND
-- loop, giving two timers running at once and effectively doubling the purchase rate.
-- hasActiveLoop is a separate flag set only by the loop itself (true when it starts, false only
-- once it actually exits), so Touched can tell "is a loop already alive" independently of the
-- count's own brief dips to zero.
function RepeatingTouch.Setup(platform: BasePart, action: (Player) -> (), debounceSchedule: ((number) -> number)?)
	local touchCounts = {} -- [player] = number of this player's body parts currently touching
	local hasActiveLoop = {} -- [player] = true from when a loop starts until it actually exits

	platform.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		touchCounts[player] = (touchCounts[player] or 0) + 1
		if hasActiveLoop[player] then return end -- a loop is already running for this player

		hasActiveLoop[player] = true
		task.spawn(function()
			local triggerCount = 0
			while (touchCounts[player] or 0) > 0 do
				action(player)
				triggerCount += 1
				-- One broadcast per actual action trigger (not a separate decorative loop), so
				-- the platform's client-side "press" animation (see init.client.luau) always
				-- reflects a real purchase/action tick rather than running on its own timer.
				Remotes.PlatformPress:FireAllClients(platform)

				local delay = debounceSchedule and debounceSchedule(triggerCount) or RepeatingTouch.DEFAULT_DEBOUNCE
				task.wait(delay)
			end
			hasActiveLoop[player] = false
		end)
	end)

	platform.TouchEnded:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or not touchCounts[player] then return end

		touchCounts[player] = math.max(touchCounts[player] - 1, 0)
	end)
end

return RepeatingTouch
