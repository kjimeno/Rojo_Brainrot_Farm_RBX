-- init.client.luau
-- This becomes StarterPlayer.StarterPlayerScripts.Client (a LocalScript).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local cash = 0

-- ===== Shop platform afford / can't-afford base color =====
-- The shop platforms are shared by every player, so the server can't set one "correct"
-- color for everyone -- each client colors the platform Part itself against its OWN cash
-- count here. Setting a property from a LocalScript only changes what this client sees, so
-- this doesn't affect other players' view of the same platform.
local AFFORD_COLOR = Color3.fromRGB(73, 201, 105)
local CANT_AFFORD_COLOR = Color3.fromRGB(255, 99, 47)

-- platform Part -> total price it represents
local trackedShopPlatforms = {}

local function colorShopPlatform(platform: BasePart, totalPrice: number)
	platform.Color = (cash >= totalPrice) and AFFORD_COLOR or CANT_AFFORD_COLOR
end

local function refreshAllShopPlatforms()
	for platform, totalPrice in pairs(trackedShopPlatforms) do
		if platform.Parent then
			colorShopPlatform(platform, totalPrice)
		else
			trackedShopPlatforms[platform] = nil
		end
	end
end

local function trackShopPlatform(instance: Instance)
	if not instance:IsA("BasePart") then return end
	local brainrotName = instance:GetAttribute("BrainrotName")
	if not brainrotName then return end

	local config = GameConfig.Brainrots[brainrotName]
	if not config then return end

	local quantity = instance:GetAttribute("Quantity") or 1
	trackedShopPlatforms[instance] = config.Price * quantity
	colorShopPlatform(instance, config.Price * quantity)
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	trackShopPlatform(descendant)
end
workspace.DescendantAdded:Connect(trackShopPlatform)

-- ===== Animated stat displays (from the purchased UI kit's "Icon" HUD element) =====
-- Same reusable structure for both Cash (Main.HUD.Left.Icon) and Energy
-- (Main.HUD.Up.Icon): an ImageLabel with "main"/"shadow" TextLabels and a "Transactions"
-- frame holding "Add"/"Subtract" badge templates. Reacts to our own Remotes.StatsUpdate
-- instead of the kit's original Player.leaderstats.*.Changed, since this game doesn't use
-- leaderstats. The tween/tick sound/floating +/- badge animation is unchanged from the kit.
-- Comma-formatted below 100,000, K/M/B/T-abbreviated above that -- see
-- GameConfig.FormatAbbreviatedNumber for the shared rule (also used server-side for
-- platform/billboard text, so both stay consistent).
local function formatNumber(amount: number): string
	return GameConfig.FormatAbbreviatedNumber(amount)
end

local ENERGY_GAIN_TEXT_MAX_ANGLE = 30 -- degrees off straight-down -- keeps it from ever drifting too horizontal
local ENERGY_GAIN_TEXT_DISTANCE_MIN = 56 -- pixels
local ENERGY_GAIN_TEXT_DISTANCE_MAX = 104 -- pixels
local ENERGY_GAIN_TEXT_FADE_DURATION = 1.4 -- fade lasts longer now
local ENERGY_GAIN_TEXT_MOVE_DURATION = 1.5 -- slightly outlasts the fade so it never visibly stops short
local ENERGY_GAIN_TEXT_MIN_SCALE = 0.45 -- badge scale for a small gain (relative to the cloned AddTemplate's own size)
local ENERGY_GAIN_TEXT_MAX_SCALE = 0.9 -- badge scale cap for a huge gain, so it can't grow unboundedly large
local ENERGY_GAIN_TEXT_SCALE_PER_DIGIT = 0.13 -- how much scale grows per extra digit in the amount (log-based, so it stays smooth across 1 up into the hundreds of millions)
local ENERGY_GAIN_TEXT_SPAWN_OFFSET_Y = 10 -- pixels down from icon-center where it first appears; the random drift then continues from there
local ENERGY_GAIN_TEXT_SPEED_JITTER = 0.25 -- +/- this fraction of ENERGY_GAIN_TEXT_MOVE_DURATION, randomized per popup, so they don't all move at identical speed

-- `icon` is the ImageLabel itself (e.g. Main.HUD.Left.Icon); `statKey` is the field name to
-- watch for in Remotes.StatsUpdate payloads (e.g. "Cash", "StoredEnergy"); `showBadgeOnDecrease`
-- controls whether decreases get the floating badge callout too (Cash: yes, Energy: no);
-- `gainStyle` picks which visual a gain uses -- "list" is Cash's stacked Transactions badge,
-- "floating" is Energy's random-downward fading "+N" text.
local function createAnimatedStatDisplay(icon: Instance, statKey: string, showBadgeOnDecrease: boolean, gainStyle: string)
	-- Icon's Size is scale-based, so its absolute pixel box changes shape as the window/viewport
	-- ratio changes -- ScaleType.Fit keeps the image itself at its own real proportions inside
	-- that box (letterboxing as needed) instead of stretching to fill whatever shape the box
	-- ends up being. A UIAspectRatioConstraint would need to already know the image's correct
	-- ratio to pin the box itself; this sidesteps that entirely by fixing it at the image level.
	if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
		(icon :: ImageLabel).ScaleType = Enum.ScaleType.Fit
	end

	local TransactionRoot = icon.main.Transactions

	local AddTemplate = TransactionRoot.Add
	local SubTemplate = TransactionRoot.Subtract
	AddTemplate.Parent = nil
	SubTemplate.Parent = nil

	local prevValue = 0
	local hasInitialized = false
	local activeRender = nil

	local tickSound = Instance.new("Sound")
	tickSound.SoundId = "rbxassetid://607665037"
	tickSound.Volume = 1
	tickSound.Parent = SoundService

	local function setLabel(amount: number)
		local formatted = formatNumber(amount)
		icon.main.Text = formatted
		icon.shadow.Text = formatted
	end

	local function tweenValue(from: number, to: number, duration: number)
		if activeRender then
			activeRender:Disconnect()
			activeRender = nil
		end

		local startTime = tick()
		local lastTick = 0

		activeRender = RunService.RenderStepped:Connect(function()
			local alpha = math.clamp((tick() - startTime) / duration, 0, 1)
			setLabel(math.floor(from + (to - from) * alpha))

			if to > from and tick() - lastTick >= 0.05 then
				lastTick = tick()
				tickSound:Play()
			end

			if alpha >= 1 then
				setLabel(to)
				activeRender:Disconnect()
				activeRender = nil
			end
		end)
	end

	local function showTransactionBadge(amount: number)
		local template = amount > 0 and AddTemplate or SubTemplate
		local badge = template:Clone()
		badge.Visible = true
		badge.Parent = TransactionRoot

		local originalSize = badge.Size
		badge.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)

		local sign = amount > 0 and "+" or "-"
		local formatted = sign .. formatNumber(math.abs(amount))
		badge.main.Text = formatted
		badge.shadow.Text = formatted

		local openInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local closeInfo = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local collapsed = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)

		local openTween = TweenService:Create(badge, openInfo, { Size = originalSize })
		openTween:Play()
		openTween.Completed:Wait()

		task.wait(2)

		local closeTween = TweenService:Create(badge, closeInfo, { Size = collapsed })
		closeTween:Play()
		closeTween.Completed:Wait()

		badge:Destroy()
	end

	-- Energy's gain callout: clones the SAME AddTemplate as the list badge above (so it keeps
	-- the kit's original font/styling) but skips the open/close size animation entirely --
	-- instead it drifts off in a random direction biased downward (never more than
	-- ENERGY_GAIN_TEXT_MAX_ANGLE off straight-down) while fading out quickly, more like a
	-- floating combat-text number than a queued notification.
	local function playEnergyGainText(amount: number)
		local badge = AddTemplate:Clone()
		badge.Visible = true
		badge.Parent = icon

		local formatted = "+" .. formatNumber(amount)
		badge.main.Text = formatted
		badge.shadow.Text = formatted

		-- The template's main/shadow labels were built for a growing left-to-right list item,
		-- so their own Position/AnchorPoint likely put them off to one side of the badge rather
		-- than centered in it. Re-centering just their ANCHOR/POSITION (not their Size, which is
		-- what TextScaled uses to compute font size -- changing it would also change how big the
		-- text renders, which is the "grows with digit count" look) keeps the exact same
		-- size/growth behavior as before, just recentered.
		for _, label in ipairs({ badge.main, badge.shadow }) do
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.new(0.5, 0, 0.5, 0)
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
		end

		-- Bigger gains get a bigger badge -- digits (log10-based) rather than the raw amount, so
		-- it scales smoothly across the full 1 to hundreds-of-millions range instead of maxing
		-- out almost immediately (or barely growing at all) with a linear formula.
		local digits = math.floor(math.log(math.max(amount, 1), 10)) + 1
		local scale = math.clamp(
			ENERGY_GAIN_TEXT_MIN_SCALE + (digits - 1) * ENERGY_GAIN_TEXT_SCALE_PER_DIGIT,
			ENERGY_GAIN_TEXT_MIN_SCALE,
			ENERGY_GAIN_TEXT_MAX_SCALE
		)

		local originalSize = badge.Size
		badge.Size = UDim2.new(
			originalSize.X.Scale * scale, originalSize.X.Offset * scale,
			originalSize.Y.Scale * scale, originalSize.Y.Offset * scale
		)

		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.5, 0, 0.5, ENERGY_GAIN_TEXT_SPAWN_OFFSET_Y)

		local angle = math.rad((math.random() * 2 - 1) * ENERGY_GAIN_TEXT_MAX_ANGLE)
		local distance = ENERGY_GAIN_TEXT_DISTANCE_MIN + math.random() * (ENERGY_GAIN_TEXT_DISTANCE_MAX - ENERGY_GAIN_TEXT_DISTANCE_MIN)
		local offsetX = math.sin(angle) * distance
		-- Drift continues from the (already-offset) spawn point, so the random downward travel
		-- stacks on top of ENERGY_GAIN_TEXT_SPAWN_OFFSET_Y rather than starting over from center.
		local offsetY = ENERGY_GAIN_TEXT_SPAWN_OFFSET_Y + math.cos(angle) * distance -- angle measured from straight down, so this is always positive (downward)

		local speedJitter = 1 + (math.random() * 2 - 1) * ENERGY_GAIN_TEXT_SPEED_JITTER
		TweenService:Create(
			badge,
			TweenInfo.new(ENERGY_GAIN_TEXT_MOVE_DURATION * speedJitter, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, offsetX, 0.5, offsetY) }
		):Play()

		local fadeInfo = TweenInfo.new(ENERGY_GAIN_TEXT_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local mainFade = TweenService:Create(badge.main, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 })
		local shadowFade = TweenService:Create(badge.shadow, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 })
		mainFade:Play()
		shadowFade:Play()

		-- The visible "stroke" is very likely a UIStroke object (its own separate .Transparency
		-- property, NOT TextStrokeTransparency), which the tweens above never touch -- that's
		-- why the fill fades smoothly but the outline just sits there opaque until badge:Destroy()
		-- yanks it away all at once. Fade every UIStroke found anywhere under the badge too.
		for _, descendant in ipairs(badge:GetDescendants()) do
			if descendant:IsA("UIStroke") then
				TweenService:Create(descendant, fadeInfo, { Transparency = 1 }):Play()
			end
		end

		mainFade.Completed:Wait()

		badge:Destroy()
	end

	Remotes.StatsUpdate.OnClientEvent:Connect(function(stats)
		local newValue = stats[statKey]
		if newValue == nil then return end

		if not hasInitialized then
			-- The first value we ever see is the loaded starting balance, not a real gain --
			-- snap to it silently, no count-up animation, no transaction badge.
			hasInitialized = true
			prevValue = newValue
			setLabel(newValue)
			return
		end

		local diff = newValue - prevValue
		if diff == 0 then return end

		-- The number itself always tweens smoothly either direction; the floating badge
		-- callout only shows for gains, unless showBadgeOnDecrease says decreases get one too.
		if diff > 0 or showBadgeOnDecrease then
			if gainStyle == "floating" then
				if diff > 0 then
					task.spawn(playEnergyGainText, diff)
				end
			else
				task.spawn(showTransactionBadge, diff)
			end
		end
		tweenValue(prevValue, newValue, 0.5)

		prevValue = newValue
	end)
end

local Main = PlayerGui:WaitForChild("Main")
createAnimatedStatDisplay(Main.HUD.Left.Icon, "Cash", true, "list")
createAnimatedStatDisplay(Main.HUD.Up.Icon, "StoredEnergy", false, "floating")

-- ===== Cash collect burst: icons burst out of the CoinVault in the air, then fly straight to you =====
local CASH_BURST_MIN_COUNT = 5
local CASH_BURST_MAX_COUNT = 6
local CASH_BURST_ICON_SIZE = UDim2.new(1, 0, 1, 0)
local CASH_BURST_MIN_DISTANCE = 16
local CASH_BURST_MAX_DISTANCE = 20
local CASH_BURST_POP_DURATION = 0.7
local CASH_BURST_MIN_ELEVATION_DEGREES = 15 -- burst direction is never shallower than this above the horizon
local CASH_BURST_GRAVITY = 25 -- studs/sec^2; slight, not full engine gravity -- just enough to arc the pop
local CASH_BURST_RETURN_MIN_SPEED = 6 -- studs/sec at the very start of the return -- slow drift
local CASH_BURST_RETURN_MAX_SPEED = 60 -- studs/sec HARD CAP it ramps up toward -- comfortably faster than the player can run, but bounded
local CASH_BURST_RETURN_ACCEL_PER_SEC = 90 -- studs/sec^2; how hard it accelerates from MIN toward the MAX cap
local CASH_BURST_RETURN_ARRIVE_DISTANCE = 1.5 -- studs; disappears once actually this close to the player
local CASH_BURST_RETURN_TIMEOUT = 4 -- safety cutoff in seconds so an edge case (e.g. character gone) can't loop forever
local CASH_TRAIL_WIDTH_STUDS = 0.9 -- total ribbon width at its widest, right at the icon
local CASH_TRAIL_TRANSPARENCY = 0.5 -- 0 = fully solid, 1 = fully invisible, for most of the ribbon's length

local cashBurstIconsFolder = Instance.new("Folder")
cashBurstIconsFolder.Name = "CashBurstIcons"
cashBurstIconsFolder.Parent = workspace

local function getMyPlot(): Instance?
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then return nil end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

-- One flying icon: bursts from `originCFrame` outward into the air, then immediately flies
-- straight to wherever the character currently is -- no stopping in between. Fine for it to
-- pass in front of the character since AlwaysOnTop is on.
--
-- IMPORTANT: this part is UNANCHORED and moved by setting real AssemblyLinearVelocity every
-- physics step, NOT by us overwriting .CFrame every frame. Trail is built to track physically
-- simulated parts; a script that repeatedly teleports an Anchored part's CFrame updates on a
-- different internal timing than Trail samples on, which is what was causing the trail to
-- visibly lead ahead of the icon (worse at high speed, since a fixed one-step timing gap turns
-- into a bigger visual gap the faster the icon moves). Letting the physics engine actually move
-- the part keeps the Trail's history in sync with the icon by construction.
local function playCashBurstIcon(originCFrame: CFrame, iconImage: string)
	local anchor = Instance.new("Part")
	anchor.Name = "CashBurstIcon"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = false
	anchor.Massless = true
	anchor.CFrame = CFrame.new(originCFrame.Position)
	anchor.Parent = cashBurstIconsFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = CASH_BURST_ICON_SIZE
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.new(1.3, 0, 1.3, 0)
	image.Image = iconImage
	image.Parent = billboard

	-- A real Trail draws a ribbon along the icon's actual motion path. Its rendered width is
	-- capped by how far apart these two attachments are -- too close together (a few tenths of
	-- a stud) and the ribbon technically exists but is too thin to see, so keep real separation.
	local trailAttachment0 = Instance.new("Attachment")
	trailAttachment0.Position = Vector3.new(-CASH_TRAIL_WIDTH_STUDS / 2, 0, 0)
	trailAttachment0.Parent = anchor

	local trailAttachment1 = Instance.new("Attachment")
	trailAttachment1.Position = Vector3.new(CASH_TRAIL_WIDTH_STUDS / 2, 0, 0)
	trailAttachment1.Parent = anchor

	local trail = Instance.new("Trail")
	trail.Attachment0 = trailAttachment0
	trail.Attachment1 = trailAttachment1
	trail.Lifetime = 0.5
	trail.MinLength = 0
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	-- Mostly at CASH_TRAIL_TRANSPARENCY along the whole ribbon, only fading further right at the
	-- very tip -- the sharp point comes from WidthScale collapsing to 0, not from a soft
	-- transparency fade blurring the shape.
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, CASH_TRAIL_TRANSPARENCY),
		NumberSequenceKeypoint.new(0.85, math.min(CASH_TRAIL_TRANSPARENCY + 0.1, 1)),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = anchor

	-- Random direction, but constrained to never be shallower than CASH_BURST_MIN_ELEVATION_DEGREES
	-- above the horizon -- picks a random compass direction (azimuth) and a random elevation
	-- angle between that minimum and straight up, instead of a fully random point in a cube.
	local azimuth = math.random() * 2 * math.pi
	local minElevation = math.rad(CASH_BURST_MIN_ELEVATION_DEGREES)
	local elevation = minElevation + math.random() * (math.rad(90) - minElevation)
	local horizontalRadius = math.cos(elevation)
	local randomDir = Vector3.new(
		math.cos(azimuth) * horizontalRadius,
		math.sin(elevation),
		math.sin(azimuth) * horizontalRadius
	)

	local burstDistance = CASH_BURST_MIN_DISTANCE + math.random() * (CASH_BURST_MAX_DISTANCE - CASH_BURST_MIN_DISTANCE)

	-- Slight gravity: we recompute the desired velocity every physics step and hand it straight
	-- to AssemblyLinearVelocity, so the part's own real gravity never gets a chance to
	-- accumulate on top of this -- our number is the only thing driving it.
	local velocity = randomDir * (burstDistance / CASH_BURST_POP_DURATION)
	anchor.AssemblyLinearVelocity = velocity
	local popStart = os.clock()
	while os.clock() - popStart < CASH_BURST_POP_DURATION do
		local dt = RunService.Heartbeat:Wait()
		velocity = velocity - Vector3.new(0, CASH_BURST_GRAVITY * dt, 0)
		anchor.AssemblyLinearVelocity = velocity
	end

	-- Chases the character's ACTUAL live position every physics step. Speed ramps linearly from
	-- CASH_BURST_RETURN_MIN_SPEED at CASH_BURST_RETURN_ACCEL_PER_SEC studs/sec^2, hard-capped at
	-- CASH_BURST_RETURN_MAX_SPEED -- comfortably faster than the player can ever run, so once
	-- it's ramped up it's guaranteed to close the gap instead of settling into matching pace.
	local returnStart = os.clock()
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			break
		end

		local toTarget = root.Position - anchor.Position
		local distance = toTarget.Magnitude
		local elapsed = os.clock() - returnStart
		if distance <= CASH_BURST_RETURN_ARRIVE_DISTANCE or elapsed > CASH_BURST_RETURN_TIMEOUT then
			break
		end

		local currentSpeed = math.min(CASH_BURST_RETURN_MIN_SPEED + CASH_BURST_RETURN_ACCEL_PER_SEC * elapsed, CASH_BURST_RETURN_MAX_SPEED)
		anchor.AssemblyLinearVelocity = toTarget.Unit * currentSpeed
		RunService.Heartbeat:Wait()
	end

	anchor.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	trail.Enabled = false
	anchor:Destroy()
end

local function playCashCollectBurst()
	local plot = getMyPlot()
	local vault = plot and plot:FindFirstChild("CoinVault")
	if not vault then return end

	local iconImage = Main.HUD.Left.Icon.Image
	local count = math.random(CASH_BURST_MIN_COUNT, CASH_BURST_MAX_COUNT)

	for _ = 1, count do
		task.spawn(playCashBurstIcon, vault.CFrame, iconImage)
	end
end

-- ===== Energy deposit rain: HUD energy icons fall down the screen when you deposit =====
-- Purely a 2D ScreenGui effect (unlike the 3D cash burst) -- icons spawn just above the top
-- edge at random horizontal spots and tween straight down past the bottom edge, then destroy.
local ENERGY_DROP_MIN_COUNT = 6
local ENERGY_DROP_MAX_COUNT = 9
local ENERGY_DROP_ICON_SIZE = UDim2.new(0, 100, 0, 100)
local ENERGY_DROP_FALL_MIN_DURATION = 1.6
local ENERGY_DROP_FALL_MAX_DURATION = 2.4
local ENERGY_DROP_STAGGER_MAX = 0.7 -- seconds; random delay before each icon starts falling, so they don't all move in lockstep
local ENERGY_DROP_DRIFT_MAX = 0.07 -- scale units of sideways drift over the fall -- gives each icon its own diagonal angle instead of falling straight down
local ENERGY_DROP_ROTATION_MAX = 50 -- degrees; each icon also spins to a random amount as it falls
local ENERGY_DROP_TOP_OFFSET = 140 -- pixels above the top edge icons spawn at -- a fixed pixel offset (not scale) so bigger icons stay fully hidden above the screen regardless of resolution
local ENERGY_DROP_SLOT_JITTER = 0.35 -- fraction of each icon's evenly-spaced slot width it's allowed to randomly shift within, so the row looks natural instead of a rigid grid

local energyDropGui = Instance.new("ScreenGui")
energyDropGui.Name = "EnergyDropEffect"
energyDropGui.ResetOnSpawn = false
energyDropGui.IgnoreGuiInset = true
energyDropGui.Parent = PlayerGui

local function playEnergyDropIcon(iconImage: string, startX: number)
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = ENERGY_DROP_ICON_SIZE
	icon.Image = iconImage
	icon.ScaleType = Enum.ScaleType.Fit -- preserves the image's real aspect ratio instead of stretching it to fill a square label
	icon.AnchorPoint = Vector2.new(0.5, 0)

	icon.Position = UDim2.new(startX, 0, 0, -ENERGY_DROP_TOP_OFFSET)
	icon.Parent = energyDropGui

	task.wait(math.random() * ENERGY_DROP_STAGGER_MAX)

	-- Each icon drifts sideways by its own random amount and spins by its own random amount,
	-- so the whole group falls at a mix of angles instead of a uniform straight drop.
	local endX = math.clamp(startX + (math.random() * 2 - 1) * ENERGY_DROP_DRIFT_MAX, -0.1, 1.1)
	local endRotation = (math.random() * 2 - 1) * ENERGY_DROP_ROTATION_MAX
	local duration = ENERGY_DROP_FALL_MIN_DURATION + math.random() * (ENERGY_DROP_FALL_MAX_DURATION - ENERGY_DROP_FALL_MIN_DURATION)
	local fallTween = TweenService:Create(
		icon,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Position = UDim2.new(endX, 0, 1.1, 0), Rotation = endRotation }
	)
	fallTween:Play()
	fallTween.Completed:Wait()

	icon:Destroy()
end

local function playEnergyDepositRain()
	local iconImage = Main.HUD.Up.Icon.Image
	local count = math.random(ENERGY_DROP_MIN_COUNT, ENERGY_DROP_MAX_COUNT)

	-- Evenly divides the screen width into `count` slots and gives each icon a small random
	-- jitter within its own slot -- spread out on purpose, not left up to pure chance, so a big
	-- batch can't randomly clump together on one side of the screen.
	local slotWidth = 1 / count
	for i = 1, count do
		local slotCenter = (i - 0.5) * slotWidth
		local jitter = (math.random() * 2 - 1) * (slotWidth * ENERGY_DROP_SLOT_JITTER)
		local startX = math.clamp(slotCenter + jitter, 0, 1)
		task.spawn(playEnergyDropIcon, iconImage, startX)
	end
end

Remotes.StatsUpdate.OnClientEvent:Connect(function(stats)
	if stats.Cash ~= nil then
		cash = stats.Cash
		refreshAllShopPlatforms()
	end

	if stats.VaultCollectedAmount ~= nil and stats.VaultCollectedAmount > 0 then
		playCashCollectBurst()
	end

	if stats.DepositedAmount ~= nil and stats.DepositedAmount > 0 then
		playEnergyDepositRain()
	end
end)

-- ===== "Home" HUD button: teleport back to your own plot's spawn point =====
-- Uses the button you built yourself in Studio (Main.HUD.Bottom.HomeButton) instead of one
-- generated by script.
local homeButton = Main.HUD.Bottom.HomeButton

-- Looks for a part named "SpawnLocation" anywhere under the player's own plot (found the same
-- way getMyPlot() finds it elsewhere in this script -- via the OwnerUserId attribute) and
-- teleports the character there, a little above the pad so they don't clip into it.
-- MouseButton1Down (fires on press) rather than Activated (fires on release), so the teleport
-- happens the instant the button is pressed, not when the mouse comes back up.
local function teleportHome()
	local plot = getMyPlot()
	if not plot then return end

	local spawnLocation = plot:FindFirstChild("SpawnLocation", true)
	if not spawnLocation then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.CFrame = spawnLocation.CFrame + Vector3.new(0, 5, 0)
end

homeButton.MouseButton1Down:Connect(teleportHome)

-- Hover/press "juice" for the Home button: grows slightly (fast) on hover, shrinks briefly on
-- press, then settles back to whichever size is currently correct -- hover size if the cursor's
-- still over it, original size otherwise. Leaving the button always wins and forces it back to
-- original size immediately, even if a press animation is still mid-flight.
local HOME_BUTTON_HOVER_SCALE = 1.12
local HOME_BUTTON_PRESS_SCALE = 0.92
local HOME_BUTTON_HOVER_DURATION = 0.12 -- fast
local HOME_BUTTON_PRESS_DURATION = 0.15

local homeButtonOriginalSize = homeButton.Size
local homeButtonHovering = false

local function tweenHomeButtonScale(scale: number, duration: number)
	local target = UDim2.new(
		homeButtonOriginalSize.X.Scale * scale, homeButtonOriginalSize.X.Offset * scale,
		homeButtonOriginalSize.Y.Scale * scale, homeButtonOriginalSize.Y.Offset * scale
	)
	return TweenService:Create(homeButton, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = target })
end

homeButton.MouseEnter:Connect(function()
	homeButtonHovering = true
	tweenHomeButtonScale(HOME_BUTTON_HOVER_SCALE, HOME_BUTTON_HOVER_DURATION):Play()
end)

homeButton.MouseLeave:Connect(function()
	homeButtonHovering = false
	tweenHomeButtonScale(1, HOME_BUTTON_HOVER_DURATION):Play()
end)

-- A quick click fires MouseButton1Down then MouseButton1Up almost immediately -- driving the
-- shrink from Down and the grow-back from Up meant the grow-back tween interrupted the shrink
-- before it ever finished. Instead, MouseButton1Down alone runs the whole press sequence:
-- shrink fully to HOME_BUTTON_PRESS_SCALE, WAIT for that to actually complete, then grow back.
-- MouseLeave (above) still overrides at any point, since it just starts a newer tween on the
-- same Size property, which cancels whatever this sequence is currently doing.
homeButton.MouseButton1Down:Connect(function()
	local shrinkTween = tweenHomeButtonScale(HOME_BUTTON_PRESS_SCALE, HOME_BUTTON_PRESS_DURATION)
	shrinkTween:Play()
	shrinkTween.Completed:Wait()
	tweenHomeButtonScale(homeButtonHovering and HOME_BUTTON_HOVER_SCALE or 1, HOME_BUTTON_PRESS_DURATION):Play()
end)

-- ===== Brainrot spawn hop: a little cosmetic bounce played whenever a brainrot spawns energy =====
-- Played entirely client-side. The server used to animate this itself, but Roblox throttles
-- CFrame replication for Anchored parts much harder than physics-simulated ones, so a
-- server-driven hop read as choppy no matter how smoothly the math was computed -- the server
-- now just tells every client "hop this model" (Remotes.BrainrotHop:FireAllClients) and each
-- client animates its own already-replicated copy locally, once per Heartbeat, no network cost.
local HOP_HEIGHT = 1.5 -- studs
local HOP_DURATION = 0.3 -- seconds, up and back down

local function playBrainrotHop(model: Model)
	if not model or not model.Parent then return end

	local standPlatform = model:FindFirstChild("StandPlatform")

	local parts = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= standPlatform and (not standPlatform or not descendant:IsDescendantOf(standPlatform)) then
			table.insert(parts, { part = descendant, originalCFrame = descendant.CFrame })
		end
	end
	if #parts == 0 then return end

	task.spawn(function()
		local startTime = os.clock()
		while model.Parent do
			local alpha = math.clamp((os.clock() - startTime) / HOP_DURATION, 0, 1)
			local heightOffset = math.sin(alpha * math.pi) * HOP_HEIGHT
			for _, entry in ipairs(parts) do
				if entry.part.Parent then
					entry.part.CFrame = entry.originalCFrame + Vector3.new(0, heightOffset, 0)
				end
			end
			if alpha >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		for _, entry in ipairs(parts) do
			if entry.part.Parent then
				entry.part.CFrame = entry.originalCFrame
			end
		end
	end)
end

Remotes.BrainrotHop.OnClientEvent:Connect(playBrainrotHop)

-- ===== Platform press: a smooth down-then-up bounce every time a platform actually triggers =====
-- Played entirely client-side for the same replication-throttling reason as the brainrot hop
-- above. RepeatingTouch.luau fires this once per real action tick (buy, deposit, collect,
-- merge, upgrade -- whichever platform), not on a separate decorative timer, so the bounce
-- always reflects something actually happening rather than running out of sync with it.
local PLATFORM_PRESS_DEPTH = 0.6 -- studs, how far down it presses
local PLATFORM_PRESS_DURATION = 0.35 -- seconds for the whole down-then-up cycle -- no pause held at the bottom

local platformOriginalCFrames = {} -- [platform] = its CFrame before any press animation ever touched it
local platformPressGeneration = {} -- [platform] = incrementing token; a newer press bails an older one out instead of fighting it

local function playPlatformPress(platform: Instance)
	if not platform or not platform:IsA("BasePart") or not platform.Parent then return end

	if not platformOriginalCFrames[platform] then
		platformOriginalCFrames[platform] = platform.CFrame
	end
	local originalCFrame = platformOriginalCFrames[platform]

	platformPressGeneration[platform] = (platformPressGeneration[platform] or 0) + 1
	local myGeneration = platformPressGeneration[platform]

	task.spawn(function()
		local startTime = os.clock()
		while platform.Parent and platformPressGeneration[platform] == myGeneration do
			local alpha = math.clamp((os.clock() - startTime) / PLATFORM_PRESS_DURATION, 0, 1)
			-- sin(alpha*pi) sweeps 0 -> 1 -> 0 smoothly across the full duration -- down and
			-- immediately back up in one continuous motion, no hold at the bottom.
			local depthOffset = math.sin(alpha * math.pi) * PLATFORM_PRESS_DEPTH
			platform.CFrame = originalCFrame - Vector3.new(0, depthOffset, 0)

			if alpha >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		if platform.Parent and platformPressGeneration[platform] == myGeneration then
			platform.CFrame = originalCFrame
		end
	end)
end

Remotes.PlatformPress.OnClientEvent:Connect(playPlatformPress)

-- ===== HUD warning popup: "Not Enough Space, Please Merge (xN)" / "Not Enough Money (xN)" =====
-- ONE shared label (parented INSIDE the Energy icon, a sibling of its floating "+N" gain texts,
-- with a ZIndex above them so it still renders on top -- Sibling ZIndexBehavior compares these
-- as true siblings) used for BOTH warning types, all at the same position. Each type keeps its
-- own "xN" count, but they share one global reset token: whichever warning fires MOST RECENTLY
-- immediately overwrites the label's text and invalidates any fade-out already scheduled by the
-- other one, so a new warning always cuts off and replaces whatever was showing rather than the
-- two stacking or fighting over the display. Every failure bumps its own count and resets a
-- fresh HOLD_DURATION window before fading -- RepeatingTouch means a player standing there gets
-- one of these per second, so it should feel alive the whole time they're stuck, then fade out
-- shortly after failures actually stop.
local WARNING_HOLD_DURATION = 4 -- seconds of no new failures (of ANY type) before it starts fading
local WARNING_FADE_DURATION = 0.5

local warningIcon = Main.HUD.Up.Icon

local warningLabel = Instance.new("TextLabel")
warningLabel.Name = "WarningLabel"
warningLabel.BackgroundTransparency = 1
warningLabel.AnchorPoint = Vector2.new(0.5, 0)
warningLabel.Position = UDim2.new(0.5, 0, 1, 18)
warningLabel.Size = UDim2.new(10, 0, 1.5, 0)
warningLabel.Font = Enum.Font.FredokaOne
warningLabel.TextScaled = true
warningLabel.TextColor3 = Color3.new(1, 1, 1)
warningLabel.TextTransparency = 1
warningLabel.TextStrokeTransparency = 1 -- always fully off -- the UIStroke below is the only visible outline now, so this doesn't double up
warningLabel.Text = ""
warningLabel.ZIndex = warningIcon.main.ZIndex + 10
warningLabel.Parent = warningIcon

-- A UIStroke gives an adjustable Thickness, unlike the built-in TextStrokeTransparency outline
-- (fixed thickness, transparency-only) -- this is what actually makes it thicker.
local warningStroke = Instance.new("UIStroke")
warningStroke.Name = "WarningStroke"
warningStroke.Color = Color3.new(0.1059, 0.1647, 0.2078)
warningStroke.Thickness = 2
warningStroke.Transparency = 0.1
warningStroke.Parent = warningLabel

local warningResetToken = 0
local activeWarningId = nil -- which trigger currently "owns" the shared label, if any

-- Returns a trigger function with its OWN independent "xN" count, but writing to the single
-- shared warningLabel/warningStroke above.
--
-- `id` distinguishes this trigger from any other sharing the same label. If a DIFFERENT id was
-- displaying when this one fires, that other trigger's count resets to 0 immediately (via
-- otherReset()) instead of only resetting whenever its own fade-out happens to run uninterrupted
-- -- which it never does once cut off, so without this its count would just silently keep
-- climbing in the background and reappear later as if it had never stopped.
local function createWarningTrigger(id: string, textFormat: string)
	local count = 0
	local function resetCount()
		count = 0
	end

	return function()
		if activeWarningId and activeWarningId.id ~= id then
			activeWarningId.reset()
		end
		activeWarningId = { id = id, reset = resetCount }

		count += 1
		warningLabel.Text = textFormat:format(count)
		warningLabel.TextTransparency = 0
		warningStroke.Transparency = 0

		-- Bumping this SHARED token invalidates any fade-out scheduled by either warning type --
		-- when THIS delay elapses, it'll be the only one whose token still matches, so it's the
		-- only one that actually fades. A different warning type firing in the meantime both
		-- cuts off the display (by overwriting .Text above) AND silently cancels this fade.
		warningResetToken += 1
		local myToken = warningResetToken

		task.delay(WARNING_HOLD_DURATION, function()
			if warningResetToken ~= myToken then return end

			local fadeInfo = TweenInfo.new(WARNING_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local fadeTween = TweenService:Create(warningLabel, fadeInfo, { TextTransparency = 1 })
			TweenService:Create(warningStroke, fadeInfo, { Transparency = 1 }):Play()
			fadeTween:Play()
			fadeTween.Completed:Wait()

			if warningResetToken == myToken then
				count = 0
				activeWarningId = nil
			end
		end)
	end
end

local showSpaceError = createWarningTrigger("space", "Not Enough Space, Please Merge (x%d)")
local showMoneyError = createWarningTrigger("money", "Not Enough Money (x%d)")

Remotes.ShopSpaceError.OnClientEvent:Connect(showSpaceError)
Remotes.MoneyError.OnClientEvent:Connect(showMoneyError)

-- Ask the server for our actual loaded stats now that we're listening for the reply above --
-- without this, everything just sits at these scripts' own built-in defaults (0, "$0", etc.)
-- until some other action (buying, depositing, ...) happens to push an update.
Remotes.RequestStats:FireServer()

-- Example client-side call (wire this to a real button later):
-- Remotes.BuyBrainrot:FireServer("Noobini Pizzanini")

print("[Client] Connected. Known brainrot tiers:")
for _, name in ipairs(GameConfig.BrainrotOrder) do
	print(" -", name, "(tier " .. GameConfig.Brainrots[name].Tier .. ")")
end
