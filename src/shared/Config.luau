-- src/shared/Config.luau
-- Central configuration: upgrade prices, timers, rebirth requirements.

export type RebirthTier = {
	cashRequired: number,
	snackrotRequired: string,
	multiplier: number,
	slotsBonus: number,
	lockBonus: number,
}

export type UpgradeData = {
	name: string,
	maxLevel: number,
	baseCost: number,
	costMultiplier: number,
	description: string,
}

local CONFIG = {
	startingCash = 200,
	sellRefundPercent = 0.5,
	baseSlotsInitial = 8,
	baseLockDurationInitial = 45,
	stealMinInterval = 60,
	stealMaxInterval = 90,
	tsunamiInterval = 150,
	tsunamiWarningDuration = 10,
	eventInterval = 180, -- 3 minutes
	eventDuration = 30,
	eventMutationMultiplier = 3,
	rebirthMaxTier = 5,
}

local REBIRTH_TIERS: { RebirthTier } = {
	{
		cashRequired = 150000,
		snackrotRequired = "Bakso Beranak",
		multiplier = 2,
		slotsBonus = 2,
		lockBonus = 15,
	},
	{
		cashRequired = 1000000,
		snackrotRequired = "Siomay Terbang",
		multiplier = 3,
		slotsBonus = 2,
		lockBonus = 15,
	},
	{
		cashRequired = 10000000,
		snackrotRequired = "Martabak Manis Galau",
		multiplier = 5,
		slotsBonus = 2,
		lockBonus = 15,
	},
	{
		cashRequired = 100000000,
		snackrotRequired = "Gudeg Gundala",
		multiplier = 8,
		slotsBonus = 2,
		lockBonus = 15,
	},
	{
		cashRequired = 1000000000,
		snackrotRequired = "Rendang Raja Rimba",
		multiplier = 12,
		slotsBonus = 2,
		lockBonus = 15,
	},
}

local UPGRADES: { UpgradeData } = {
	{
		name = "RunSpeed",
		maxLevel = 5,
		baseCost = 500,
		costMultiplier = 2.5,
		description = "+15% run speed per level",
	},
	{
		name = "CarryBag",
		maxLevel = 3,
		baseCost = 1000,
		costMultiplier = 5,
		description = "Carry more Snackrot at once (1->3)",
	},
	{
		name = "GembokWarung",
		maxLevel = 1,
		baseCost = 5000,
		costMultiplier = 1,
		description = "+30s base lock duration",
	},
	{
		name = "AnjingPenjaga",
		maxLevel = 1,
		baseCost = 20000,
		costMultiplier = 1,
		description = "Auto-chases 1 thief away",
	},
}

local function getRebirthTier(tier: number): RebirthTier?
	return REBIRTH_TIERS[tier]
end

local function getAllRebirthTiers(): { RebirthTier }
	return REBIRTH_TIERS
end

local function getUpgradeData(name: string): UpgradeData?
	for _, upgrade in UPGRADES do
		if upgrade.name == name then
			return upgrade
		end
	end
	return nil
end

local function getAllUpgrades(): { UpgradeData }
	return UPGRADES
end

local function getUpgradeCost(upgradeName: string, currentLevel: number): number
	local upgrade = getUpgradeData(upgradeName)
	if not upgrade then return 0 end
	if currentLevel >= upgrade.maxLevel then return 0 end
	return math.floor(upgrade.baseCost * (upgrade.costMultiplier ^ currentLevel))
end

local function getMaxSlots(rebirthTier: number): number
	local base = CONFIG.baseSlotsInitial
	for i = 1, math.min(rebirthTier, #REBIRTH_TIERS) do
		base += REBIRTH_TIERS[i].slotsBonus
	end
	return math.min(base, 16)
end

local function getLockDuration(rebirthTier: number): number
	local base = CONFIG.baseLockDurationInitial
	for i = 1, math.min(rebirthTier, #REBIRTH_TIERS) do
		base += REBIRTH_TIERS[i].lockBonus
	end
	return base
end

local function getIncomeMultiplier(rebirthTier: number): number
	if rebirthTier <= 0 then return 1 end
	if rebirthTier > #REBIRTH_TIERS then rebirthTier = #REBIRTH_TIERS end
	return REBIRTH_TIERS[rebirthTier].multiplier
end

return {
	CONFIG = CONFIG,
	REBIRTH_TIERS = REBIRTH_TIERS,
	UPGRADES = UPGRADES,
	getRebirthTier = getRebirthTier,
	getAllRebirthTiers = getAllRebirthTiers,
	getUpgradeData = getUpgradeData,
	getAllUpgrades = getAllUpgrades,
	getUpgradeCost = getUpgradeCost,
	getMaxSlots = getMaxSlots,
	getLockDuration = getLockDuration,
	getIncomeMultiplier = getIncomeMultiplier,
}