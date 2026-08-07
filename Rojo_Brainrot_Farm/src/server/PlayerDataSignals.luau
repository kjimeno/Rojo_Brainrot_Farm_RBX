-- PlayerDataSignals.luau
-- Lives at ServerScriptService.Server.PlayerDataSignals
-- Tiny pub/sub so systems that don't already depend on each other (e.g. EnergyConversionSystem
-- and ShopPrompts) can still react to "this player's Cash/ShopTier just changed" -- without
-- requiring each other directly, which would create a circular require (ShopPrompts already
-- requires EnergyConversionSystem for GetPlayerPlot/UpdateBoard).

local PlayerDataSignals = {}

local cashChangedListeners: { (Player) -> () } = {}
local shopTierChangedListeners: { (Player) -> () } = {}

function PlayerDataSignals.OnCashChanged(callback: (Player) -> ())
	table.insert(cashChangedListeners, callback)
end

-- Call whenever data.Cash changes for a player, from wherever it happened.
function PlayerDataSignals.FireCashChanged(player: Player)
	for _, callback in ipairs(cashChangedListeners) do
		callback(player)
	end
end

function PlayerDataSignals.OnShopTierChanged(callback: (Player) -> ())
	table.insert(shopTierChangedListeners, callback)
end

-- Call whenever data.ShopTier changes for a player.
function PlayerDataSignals.FireShopTierChanged(player: Player)
	for _, callback in ipairs(shopTierChangedListeners) do
		callback(player)
	end
end

return PlayerDataSignals
