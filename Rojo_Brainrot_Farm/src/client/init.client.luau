-- init.client.luau
-- This becomes StarterPlayer.StarterPlayerScripts.Client (a LocalScript).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local player = Players.LocalPlayer

-- ===== Bottom-of-screen energy counter =====
-- StatsUpdate only ever sends the fields that changed, so we keep a running
-- total locally and just overwrite whichever keys show up in each event.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EnergyHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

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

-- ===== Bottom-left cash counter =====
local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.AnchorPoint = Vector2.new(0, 1)
cashLabel.Position = UDim2.new(0, 20, 1, -20)
cashLabel.Size = UDim2.new(0, 220, 0, 40)
cashLabel.BackgroundTransparency = 0.4
cashLabel.BackgroundColor3 = Color3.new(0, 0, 0)
cashLabel.TextColor3 = Color3.fromRGB(60, 200, 100)
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextScaled = true
cashLabel.Text = "Cash: 0"
cashLabel.Parent = screenGui

local storedEnergy = 0
local cash = 0

-- ===== Shop platform afford / can't-afford base color =====
-- The shop platforms are shared by every player, so the server can't set one "correct"
-- color for everyone -- each client colors the platform Part itself against its OWN cash
-- count here. Setting a property from a LocalScript only changes what this client sees, so
-- this doesn't affect other players' view of the same platform.
local AFFORD_COLOR = Color3.fromRGB(85, 255, 127)
local CANT_AFFORD_COLOR = Color3.fromRGB(255, 60, 60)

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

local function trackShopPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then return end
	local brainrotName = prompt:GetAttribute("BrainrotName")
	if not brainrotName then return end

	local config = GameConfig.Brainrots[brainrotName]
	if not config then return end

	local platform = prompt.Parent
	if not platform or not platform:IsA("BasePart") then return end

	local quantity = prompt:GetAttribute("Quantity") or 1
	trackedShopPlatforms[platform] = config.Price * quantity
	colorShopPlatform(platform, config.Price * quantity)
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	trackShopPrompt(descendant)
end
workspace.DescendantAdded:Connect(trackShopPrompt)

Remotes.StatsUpdate.OnClientEvent:Connect(function(stats)
	if stats.StoredEnergy ~= nil then
		storedEnergy = stats.StoredEnergy
		energyLabel.Text = ("Energy: %d"):format(storedEnergy)
	end

	if stats.Cash ~= nil then
		cash = stats.Cash
		cashLabel.Text = ("Cash: %d"):format(cash)
		refreshAllShopPlatforms()
	end
end)

-- Example client-side call (wire this to a real button later):
-- Remotes.BuyBrainrot:FireServer("Tralalero")

print("[Client] Connected. Known brainrot tiers:")
for _, name in ipairs(GameConfig.BrainrotOrder) do
	print(" -", name, "(tier " .. GameConfig.Brainrots[name].Tier .. ")")
end
