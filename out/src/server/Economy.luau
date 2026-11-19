-- src/server/Economy.luau
-- One job: money. Buying, selling, upgrades, and the one-second income heartbeat.
-- Storytellers: tickIncome, buySnackrot, sellSnackrot, buyUpgrade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SnackrotDB = require(Shared.SnackrotDB)
local Config = require(Shared.Config)
local SnackrotLabel = require(Shared.SnackrotLabel)

local GameState = require(script.Parent.GameState)
local Base = require(script.Parent.Base)
local JuiceFX = require(script.Parent.JuiceFX)

local Economy = {}

local INCOME_INTERVAL = 1
local eventIncomeMultiplier = 1
local ticking = false

local function getRemotes(): Folder?
	return ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
end

local function notifyPlayer(player: Player, message: string, kind: string)
	local remotes = getRemotes()
	if not remotes then return end
	local remote = remotes:FindFirstChild("NotificationEvent")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, message, kind)
	end
end

local function broadcastIncome(player: Player)
	local remotes = getRemotes()
	if not remotes then return end
	local remote = remotes:FindFirstChild("IncomeTick")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, GameState.getCash(player), GameState.getTotalIncomePerSec(player))
	end
end

-- "You need $50 more / Kamu butuh $50 lagi" reads better than a bare error code.
local function shortfallMessage(missing: number): string
	return "Not enough cash / Uang tidak cukup (" .. SnackrotLabel.formatMoney(missing) .. " short / kurang)"
end

-- tickIncome: one heartbeat for every player. Money only ever moves here or in a sale.
local function tickIncome()
	ticking = true
	task.spawn(function()
		while ticking do
			task.wait(INCOME_INTERVAL)
			for _, player in Players:GetPlayers() do
				local income = GameState.getTotalIncomePerSec(player)
				if income > 0 then
					local gain = income * eventIncomeMultiplier
					GameState.addCash(player, gain)
					broadcastIncome(player)
				end
			end
		end
	end)
end

local function stopTickIncome()
	ticking = false
end

local function countPlacedCopies(player: Player, snackrotName: string): number
	local placed = 0
	for _, name in GameState.getEquippedSnackrots(player) do
		if name == snackrotName then
			placed += 1
		end
	end
	return placed
end

-- buySnackrot: the only way new Snackrot enters the world. Everything is checked here.
local function buySnackrot(player: Player, snackrotName: string, mutationName: string?): (boolean, string)
	local snackrot = SnackrotDB.getSnackrotByName(snackrotName)
	if not snackrot then
		return false, "Unknown Snackrot / Snackrot tidak dikenal"
	end

	if snackrot.eventOnly then
		local eventsModule = script.Parent:FindFirstChild("Events")
		local eventActive = false
		if eventsModule then
			local Events = require(eventsModule)
			eventActive = Events.isGoldenRainActive()
		end
		if not eventActive then
			return false, "Event only / Hanya saat event"
		end
	end

	local state = GameState.getState(player)
	if state.slotsUnlocked <= 0 then
		return false, "No slots / Tidak ada slot"
	end

	local totalOwned = 0
	for _, entry in state.ownedSnackrots do
		totalOwned += entry.count
	end
	if totalOwned >= state.slotsUnlocked then
		return false, "Base full / Base penuh (" .. totalOwned .. "/" .. state.slotsUnlocked .. ")"
	end

	local cost = snackrot.cost
	if GameState.getCash(player) < cost then
		return false, shortfallMessage(cost - GameState.getCash(player))
	end

	local resolvedMutation = mutationName
	if not resolvedMutation then
		local rolled = SnackrotDB.rollMutation()
		if rolled then
			resolvedMutation = rolled.name
		end
	end

	GameState.addCash(player, -cost)
	GameState.addOwnedSnackrot(player, snackrotName, resolvedMutation)
	broadcastIncome(player)

	local message = "Bought " .. snackrotName .. " / Membeli " .. snackrotName
	if resolvedMutation then
		message = message .. " [" .. resolvedMutation .. "]"
	end
	notifyPlayer(player, message, "good")

	return true, message
end

-- sellSnackrot: half price back, but never for a Snackrot that is standing on the base.
local function sellSnackrot(player: Player, snackrotName: string): (boolean, string)
	local snackrot = SnackrotDB.getSnackrotByName(snackrotName)
	if not snackrot then
		return false, "Unknown Snackrot / Snackrot tidak dikenal"
	end

	local owned = GameState.getOwnedSnackrots(player)
	local entry = owned[snackrotName]
	if not entry or entry.count <= 0 then
		return false, "You do not own this / Kamu belum punya ini"
	end

	if countPlacedCopies(player, snackrotName) >= entry.count then
		return false, "Lift it from the base first / Angkat dari base dulu"
	end

	local refund = math.floor(snackrot.cost * Config.CONFIG.sellRefundPercent)
	GameState.removeOwnedSnackrot(player, snackrotName)
	GameState.addCash(player, refund)
	broadcastIncome(player)

	notifyPlayer(player, "Sold " .. snackrotName .. " for " .. SnackrotLabel.formatMoney(refund) .. " / Terjual", "info")
	return true, "Sold " .. snackrotName .. " +" .. SnackrotLabel.formatMoney(refund) .. " / Terjual +" .. SnackrotLabel.formatMoney(refund)
end

-- RunSpeed changes the character; every other upgrade is read where it is spent.
local function applyUpgradeEffects(player: Player)
	local level = GameState.getUpgradeLevel(player, "RunSpeed")
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16 * (1 + 0.15 * level)
		end
	end
end

local function buyUpgrade(player: Player, upgradeName: string): (boolean, string)
	local upgrade = Config.getUpgradeData(upgradeName)
	if not upgrade then
		return false, "Unknown upgrade / Upgrade tidak dikenal"
	end

	local level = GameState.getUpgradeLevel(player, upgradeName)
	if level >= upgrade.maxLevel then
		return false, "Max level / Level maksimal"
	end

	local cost = Config.getUpgradeCost(upgradeName, level)
	if GameState.getCash(player) < cost then
		return false, shortfallMessage(cost - GameState.getCash(player))
	end

	GameState.addCash(player, -cost)
	GameState.setUpgradeLevel(player, upgradeName, level + 1)
	applyUpgradeEffects(player)
	broadcastIncome(player)

	notifyPlayer(player, upgradeName .. " Lv." .. (level + 1) .. " / Level " .. (level + 1), "gold")
	return true, upgradeName .. " -> Lv." .. (level + 1) .. " / Naik ke level " .. (level + 1)
end

local function getCarryCapacity(player: Player): number
	return 1 + GameState.getUpgradeLevel(player, "CarryBag")
end

local function getRunSpeedMultiplier(player: Player): number
	return 1 + 0.15 * GameState.getUpgradeLevel(player, "RunSpeed")
end

local function hasGuardDog(player: Player): boolean
	return GameState.getUpgradeLevel(player, "AnjingPenjaga") > 0
end

-- Golden Rain pays double; the multiplier lives here so only money code touches money.
local function setEventIncomeMultiplier(multiplier: number)
	eventIncomeMultiplier = math.max(1, multiplier)
end

local function getEventIncomeMultiplier(): number
	return eventIncomeMultiplier
end

return {
	tickIncome = tickIncome,
	stopTickIncome = stopTickIncome,
	buySnackrot = buySnackrot,
	sellSnackrot = sellSnackrot,
	buyUpgrade = buyUpgrade,
	applyUpgradeEffects = applyUpgradeEffects,
	getCarryCapacity = getCarryCapacity,
	getRunSpeedMultiplier = getRunSpeedMultiplier,
	hasGuardDog = hasGuardDog,
	setEventIncomeMultiplier = setEventIncomeMultiplier,
	getEventIncomeMultiplier = getEventIncomeMultiplier,
	broadcastIncome = broadcastIncome,
}
