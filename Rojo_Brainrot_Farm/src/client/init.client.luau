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
local function formatNumber(amount: number): string
	local isNegative = amount < 0
	local digits = tostring(math.floor(math.abs(amount)))
	local reversed = digits:reverse():gsub("(%d%d%d)", "%1,"):gsub(",$", "")
	return (isNegative and "-" or "") .. reversed:reverse()
end

-- `icon` is the ImageLabel itself (e.g. Main.HUD.Left.Icon); `statKey` is the field name to
-- watch for in Remotes.StatsUpdate payloads (e.g. "Cash", "StoredEnergy"); `showBadgeOnDecrease`
-- controls whether decreases get the floating badge callout too (Cash: yes, Energy: no).
local function createAnimatedStatDisplay(icon: Instance, statKey: string, showBadgeOnDecrease: boolean)
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
			task.spawn(showTransactionBadge, diff)
		end
		tweenValue(prevValue, newValue, 0.5)

		prevValue = newValue
	end)
end

local Main = PlayerGui:WaitForChild("Main")
createAnimatedStatDisplay(Main.HUD.Left.Icon, "Cash", true)
createAnimatedStatDisplay(Main.HUD.Up.Icon, "StoredEnergy", false)

-- ===== Cash collect burst: icons burst out of the CoinVault in the air, then fly straight to you =====
local CASH_BURST_MIN_COUNT = 5
local CASH_BURST_MAX_COUNT = 6
local CASH_BURST_ICON_SIZE = UDim2.new(1, 0, 1, 0)
local CASH_BURST_MIN_DISTANCE = 10
local CASH_BURST_MAX_DISTANCE = 15
local CASH_BURST_POP_DURATION = 0.35
local CASH_BURST_RETURN_DURATION = 0.4

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
local function playCashBurstIcon(originCFrame: CFrame, iconImage: string)
	local anchor = Instance.new("Part")
	anchor.Name = "CashBurstIcon"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.CFrame = originCFrame
	anchor.Parent = cashBurstIconsFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = CASH_BURST_ICON_SIZE
	billboard.AlwaysOnTop = true
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.new(1, 0, 1, 0)
	image.Image = iconImage
	image.Parent = billboard

	-- A real Trail draws a ribbon along the icon's actual motion path. Its rendered width is
	-- capped by how far apart these two attachments are -- too close together (a few tenths of
	-- a stud) and the ribbon technically exists but is too thin to see, so keep real separation.
	local trailAttachment0 = Instance.new("Attachment")
	trailAttachment0.Position = Vector3.new(-0.75, 0, 0)
	trailAttachment0.Parent = anchor

	local trailAttachment1 = Instance.new("Attachment")
	trailAttachment1.Position = Vector3.new(0.75, 0, 0)
	trailAttachment1.Parent = anchor

	local trail = Instance.new("Trail")
	trail.Attachment0 = trailAttachment0
	trail.Attachment1 = trailAttachment1
	trail.Lifetime = 0.5
	trail.MinLength = 0
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 236, 130))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = anchor

	-- Fully random direction (not just up/outward) -- pick a random point in a cube and
	-- normalize it into a random unit direction, then scale to a random burst distance.
	local randomDir = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	if randomDir.Magnitude < 0.001 then
		randomDir = Vector3.new(0, 1, 0)
	end
	randomDir = randomDir.Unit
	local burstDistance = CASH_BURST_MIN_DISTANCE + math.random() * (CASH_BURST_MAX_DISTANCE - CASH_BURST_MIN_DISTANCE)
	local burstCFrame = originCFrame + (randomDir * burstDistance)

	local popTween = TweenService:Create(
		anchor,
		TweenInfo.new(CASH_BURST_POP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ CFrame = burstCFrame }
	)
	popTween:Play()
	popTween.Completed:Wait()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local returnCFrame = (root and root.CFrame) or burstCFrame

	local returnTween = TweenService:Create(
		anchor,
		TweenInfo.new(CASH_BURST_RETURN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = returnCFrame }
	)
	returnTween:Play()
	returnTween.Completed:Wait()

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

Remotes.StatsUpdate.OnClientEvent:Connect(function(stats)
	if stats.Cash ~= nil then
		cash = stats.Cash
		refreshAllShopPlatforms()
	end

	if stats.VaultCollectedAmount ~= nil and stats.VaultCollectedAmount > 0 then
		playCashCollectBurst()
	end
end)

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
