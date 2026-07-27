-- PlayerDataManager.luau
-- Lives at ServerScriptService.Server.PlayerDataManager
-- Handles loading/saving player data with retry logic.

local DataStoreService = game:GetService("DataStoreService")

local PlayerDataManager = {}
PlayerDataManager.Cache = {} -- [player] = dataTable

local DataStore = DataStoreService:GetDataStore("BrainrotTycoon_v1")

local DEFAULT_DATA = {
	Cash = 100,
	StoredEnergy = 0,
	SiloEnergy = 0,
	PendingCash = 0,
	ConversionLevel = 0,
	OwnedBrainrots = {}, -- { {Name = "Noobini Pizzanini", Id = "uuid"}, ... }
}

local function deepCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = (type(v) == "table") and deepCopy(v) or v
	end
	return copy
end

function PlayerDataManager.Load(player: Player)
	local key = "Player_" .. player.UserId
	local success, result = pcall(function()
		return DataStore:GetAsync(key)
	end)

	local data
	if success and result then
		data = result
		for k, v in pairs(DEFAULT_DATA) do
			if data[k] == nil then
				data[k] = (type(v) == "table") and deepCopy(v) or v
			end
		end
	else
		data = deepCopy(DEFAULT_DATA)
		if not success then
			warn("[PlayerDataManager] Failed to load data for " .. player.Name .. ": " .. tostring(result))
		end
	end

	PlayerDataManager.Cache[player] = data
	return data
end

function PlayerDataManager.Get(player: Player)
	return PlayerDataManager.Cache[player]
end

function PlayerDataManager.Save(player: Player)
	local data = PlayerDataManager.Cache[player]
	if not data then return end

	local key = "Player_" .. player.UserId
	local success, err = pcall(function()
		DataStore:SetAsync(key, data)
	end)

	if not success then
		warn("[PlayerDataManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

function PlayerDataManager.Release(player: Player)
	PlayerDataManager.Save(player)
	PlayerDataManager.Cache[player] = nil
end

function PlayerDataManager.StartAutosave(intervalSeconds: number)
	task.spawn(function()
		while true do
			task.wait(intervalSeconds)
			for player, _ in pairs(PlayerDataManager.Cache) do
				PlayerDataManager.Save(player)
			end
		end
	end)
end

return PlayerDataManager
