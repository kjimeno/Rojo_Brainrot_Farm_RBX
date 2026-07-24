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

-- ===== Bottom-left coin counter =====
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.AnchorPoint = Vector2.new(0, 1)
coinsLabel.Position = UDim2.new(0, 20, 1, -20)
coinsLabel.Size = UDim2.new(0, 220, 0, 40)
coinsLabel.BackgroundTransparency = 0.4
coinsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.TextScaled = true
coinsLabel.Text = "Coins: 0"
coinsLabel.Parent = screenGui

local storedEnergy = 0
local coins = 0

Remotes.StatsUpdate.OnClientEvent:Connect(function(stats)
	if stats.StoredEnergy ~= nil then
		storedEnergy = stats.StoredEnergy
		energyLabel.Text = ("Energy: %d"):format(storedEnergy)
	end

	if stats.Coins ~= nil then
		coins = stats.Coins
		coinsLabel.Text = ("Coins: %d"):format(coins)
	end
end)

-- Example client-side call (wire this to a real button later):
-- Remotes.BuyBrainrot:FireServer("Tralalero")

print("[Client] Connected. Known brainrot tiers:")
for _, name in ipairs(GameConfig.BrainrotOrder) do
	print(" -", name, "(tier " .. GameConfig.Brainrots[name].Tier .. ")")
end
