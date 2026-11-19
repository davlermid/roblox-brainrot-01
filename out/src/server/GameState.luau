-- src/server/GameState.luau
-- THE single source of state: cash, owned, slots, lockUntil, rebirth, upgrades.
-- Every module reads state from here; no duplicate state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SnackrotDB = require(Shared.SnackrotDB)
local Config = require(Shared.Config)

export type PlayerState = {
	cash: number,
	ownedSnackrots: { [string]: { count: number, mutations: { [string]: number } } },
	equippedSnackrots: { [number]: string? }, -- slot index -> snackrot name
	slotsUnlocked: number,
	lockUntil: number, -- timestamp when lock expires
	rebirthTier: number,
	upgrades: { [string]: number }, -- upgrade name -> level
	totalIncomePerSec: number,
}

local playerStates: { [Player]: PlayerState } = {}

local function createDefaultState(): PlayerState
	return {
		cash = Config.CONFIG.startingCash,
		ownedSnackrots = {},
		equippedSnackrots = {},
		slotsUnlocked = Config.CONFIG.baseSlotsInitial,
		lockUntil = os.time() + Config.CONFIG.baseLockDurationInitial,
		rebirthTier = 0,
		upgrades = {
			RunSpeed = 0,
			CarryBag = 0,
			GembokWarung = 0,
			AnjingPenjaga = 0,
		},
		totalIncomePerSec = 0,
	}
end

local function getState(player: Player): PlayerState
	if not playerStates[player] then
		playerStates[player] = createDefaultState()
	end
	return playerStates[player]
end

local function setCash(player: Player, amount: number)
	local state = getState(player)
	state.cash = math.max(0, math.floor(amount))
end

local function addCash(player: Player, amount: number)
	local state = getState(player)
	state.cash = math.max(0, math.floor(state.cash + amount))
end

local function getCash(player: Player): number
	return getState(player).cash
end

local recalculateIncome

local function addOwnedSnackrot(player: Player, snackrotName: string, mutation: string?)
	local state = getState(player)
	if not state.ownedSnackrots[snackrotName] then
		state.ownedSnackrots[snackrotName] = { count = 0, mutations = {} }
	end
	state.ownedSnackrots[snackrotName].count += 1
	if mutation then
		state.ownedSnackrots[snackrotName].mutations[mutation] = (state.ownedSnackrots[snackrotName].mutations[mutation] or 0) + 1
	end
	recalculateIncome(player)
end

local function removeOwnedSnackrot(player: Player, snackrotName: string, mutation: string?): boolean
	local state = getState(player)
	local owned = state.ownedSnackrots[snackrotName]
	if not owned or owned.count <= 0 then return false end
	
	owned.count -= 1
	if mutation and owned.mutations[mutation] and owned.mutations[mutation] > 0 then
		owned.mutations[mutation] -= 1
		if owned.mutations[mutation] <= 0 then
			owned.mutations[mutation] = nil
		end
	end
	if owned.count <= 0 then
		state.ownedSnackrots[snackrotName] = nil
	end
	recalculateIncome(player)
	return true
end

local function getOwnedSnackrots(player: Player): { [string]: { count: number, mutations: { [string]: number } } }
	return getState(player).ownedSnackrots
end

local function equipSnackrot(player: Player, slotIndex: number, snackrotName: string): boolean
	local state = getState(player)
	if slotIndex < 1 or slotIndex > state.slotsUnlocked then return false end
	
	local owned = state.ownedSnackrots[snackrotName]
	if not owned or owned.count <= 0 then return false end
	
	-- Unequip from previous slot if any
	for i, name in state.equippedSnackrots do
		if name == snackrotName then
			state.equippedSnackrots[i] = nil
			break
		end
	end
	
	state.equippedSnackrots[slotIndex] = snackrotName
	recalculateIncome(player)
	return true
end

local function unequipSnackrot(player: Player, slotIndex: number): string?
	local state = getState(player)
	local name = state.equippedSnackrots[slotIndex]
	state.equippedSnackrots[slotIndex] = nil
	recalculateIncome(player)
	return name
end

local function getEquippedSnackrots(player: Player): { [number]: string? }
	return getState(player).equippedSnackrots
end

local function getSlotCount(player: Player): number
	return getState(player).slotsUnlocked
end

local function setLockUntil(player: Player, timestamp: number)
	getState(player).lockUntil = timestamp
end

local function getLockUntil(player: Player): number
	return getState(player).lockUntil
end

local function isBaseLocked(player: Player): boolean
	return os.time() < getState(player).lockUntil
end

local function addLockTime(player: Player, seconds: number)
	local state = getState(player)
	state.lockUntil = math.max(state.lockUntil, os.time()) + seconds
end

local function getRebirthTier(player: Player): number
	return getState(player).rebirthTier
end

local function setRebirthTier(player: Player, tier: number)
	getState(player).rebirthTier = tier
end

local function getUpgradeLevel(player: Player, upgradeName: string): number
	return getState(player).upgrades[upgradeName] or 0
end

local function setUpgradeLevel(player: Player, upgradeName: string, level: number)
	getState(player).upgrades[upgradeName] = level
end

local function getAllUpgrades(player: Player): { [string]: number }
	return getState(player).upgrades
end

function recalculateIncome(player: Player)
	local state = getState(player)
	local total = 0
	for snackrotName, data in state.ownedSnackrots do
		local snackrot = SnackrotDB.getSnackrotByName(snackrotName)
		if snackrot then
			local baseIncome = snackrot.incomePerSec * data.count
			-- Apply mutation multipliers
			for mutationName, count in data.mutations do
				local mutation = SnackrotDB.getMutationByName(mutationName)
				if mutation then
					baseIncome = baseIncome * mutation.incomeMultiplier
				end
			end
			total += baseIncome
		end
	end
	
	local multiplier = Config.getIncomeMultiplier(state.rebirthTier)
	state.totalIncomePerSec = math.floor(total * multiplier)
end

local function getTotalIncomePerSec(player: Player): number
	return getState(player).totalIncomePerSec
end

local function resetPlayerState(player: Player)
	playerStates[player] = createDefaultState()
end

local function onPlayerRemoving(player: Player)
	playerStates[player] = nil
end

game.Players.PlayerRemoving:Connect(onPlayerRemoving)

return {
	getState = getState,
	createDefaultState = createDefaultState,
	setCash = setCash,
	addCash = addCash,
	getCash = getCash,
	addOwnedSnackrot = addOwnedSnackrot,
	removeOwnedSnackrot = removeOwnedSnackrot,
	getOwnedSnackrots = getOwnedSnackrots,
	equipSnackrot = equipSnackrot,
	unequipSnackrot = unequipSnackrot,
	getEquippedSnackrots = getEquippedSnackrots,
	getSlotCount = getSlotCount,
	setLockUntil = setLockUntil,
	getLockUntil = getLockUntil,
	isBaseLocked = isBaseLocked,
	addLockTime = addLockTime,
	getRebirthTier = getRebirthTier,
	setRebirthTier = setRebirthTier,
	getUpgradeLevel = getUpgradeLevel,
	setUpgradeLevel = setUpgradeLevel,
	getAllUpgrades = getAllUpgrades,
	recalculateIncome = recalculateIncome,
	getTotalIncomePerSec = getTotalIncomePerSec,
	resetPlayerState = resetPlayerState,
}