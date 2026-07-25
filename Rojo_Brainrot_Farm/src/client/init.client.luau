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

-- ===== Bottom-of-screen energy counter =====
-- StatsUpdate only ever sends the fields that changed, so we keep a running
-- total locally and just overwrite whichever keys show up in each event.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EnergyHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local energyLabel = Instance.new("TextLabel")
energyLabel.Name = "EnergyLabel"
energyLabel.AnchorPoint = Vector2.new(0.5, 1)
energyLabel.Position = UDim2.new(0.5, 0, 1, -20)
energyLabel.Size = UDim2.new(0, 300, 0, 40)
energyLabel.BackgroundTransparency = 0.4
energyLabel.BackgroundColor3 = Color3.new(0, 0, 0)
energyLabel.TextColor3 = Color3.new(1, 1, 1)
energyLabel.Font = Enum.Font.GothamBold
energyLabel.TextScaled = true
energyLabel.Text = "Energy: 0"
energyLabel.Parent = screenGui

local storedEnergy = 0
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

-- ===== Cash display (from the purchased UI kit's "Icon" HUD element) =====
-- Lives at PlayerGui.Main.HUD.Left.Icon. Reacts to our own Remotes.StatsUpdate instead of the
-- kit's original Player.leaderstats.Cash.Changed, since this game doesn't use leaderstats for
-- cash. Everything else (the tween, tick sound, floating +/- transaction badge) is unchanged
-- from the kit.
local function formatNumber(amount: number): string
	local isNegative = amount < 0
	local digits = tostring(math.floor(math.abs(amount)))
	local reversed = digits:reverse():gsub("(%d%d%d)", "%1,"):gsub(",$", "")
	return (isNegative and "-" or "") .. reversed:reverse()
end

local function initCashDisplay()
	local Main = PlayerGui:WaitForChild("Main")
	local CashLabel = Main.HUD.Left.Icon
	local TransactionRoot = CashLabel.main.Transactions

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

	local function setCashLabel(amount: number)
		local formatted = formatNumber(amount)
		CashLabel.main.Text = formatted
		CashLabel.shadow.Text = formatted
	end

	local function tweenCashValue(from: number, to: number, duration: number)
		if activeRender then
			activeRender:Disconnect()
			activeRender = nil
		end

		local startTime = tick()
		local lastTick = 0

		activeRender = RunService.RenderStepped:Connect(function()
			local alpha = math.clamp((tick() - startTime) / duration, 0, 1)
			setCashLabel(math.floor(from + (to - from) * alpha))

			if to > from and tick() - lastTick >= 0.05 then
				lastTick = tick()
				tickSound:Play()
			end

			if alpha >= 1 then
				setCashLabel(to)
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
		if stats.Cash == nil then return end
		local newValue = stats.Cash

		if not hasInitialized then
			-- The first value we ever see is the loaded starting balance, not a real gain --
			-- snap to it silently, no count-up animation, no transaction badge.
			hasInitialized = true
			prevValue = newValue
			setCashLabel(newValue)
			return
		end

		local diff = newValue - prevValue
		if diff == 0 then return end

		task.spawn(showTransactionBadge, diff)
		tweenCashValue(prevValue, newValue, 0.5)

		prevValue = newValue
	end)
end

initCashDisplay()

Remotes.StatsUpdate.OnClientEvent:Connect(function(stats)
	if stats.StoredEnergy ~= nil then
		storedEnergy = stats.StoredEnergy
		energyLabel.Text = ("Energy: %d"):format(storedEnergy)
	end

	if stats.Cash ~= nil then
		cash = stats.Cash
		refreshAllShopPlatforms()
	end
end)

-- Ask the server for our actual loaded stats now that we're listening for the reply above --
-- without this, everything just sits at these scripts' own built-in defaults (Energy: 0,
-- Cash: 0, etc.) until some other action (buying, depositing, ...) happens to push an update.
Remotes.RequestStats:FireServer()

-- Example client-side call (wire this to a real button later):
-- Remotes.BuyBrainrot:FireServer("Tralalero")

print("[Client] Connected. Known brainrot tiers:")
for _, name in ipairs(GameConfig.BrainrotOrder) do
	print(" -", name, "(tier " .. GameConfig.Brainrots[name].Tier .. ")")
end
