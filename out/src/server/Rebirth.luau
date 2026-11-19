-- src/server/Rebirth.luau
-- One job: rebirth. Trade everything you own for a permanent multiplier and more slots.
-- Storytellers: canRebirth, doRebirth, getRebirthInfo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SnackrotDB = require(Shared.SnackrotDB)
local Config = require(Shared.Config)
local SnackrotLabel = require(Shared.SnackrotLabel)

local GameState = require(script.Parent.GameState)
local Base = require(script.Parent.Base)
local JuiceFX = require(script.Parent.JuiceFX)

local Rebirth = {}

local function getRemotes(): Folder?
	return ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
end

local function fireBanner(player: Player, title: string, subtitle: string, duration: number)
	local remotes = getRemotes()
	if not remotes then return end
	local remote = remotes:FindFirstChild("BannerEvent")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, title, subtitle, duration)
	end
end

local function notifyPlayer(player: Player, message: string, kind: string)
	local remotes = getRemotes()
	if not remotes then return end
	local remote = remotes:FindFirstChild("NotificationEvent")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, message, kind)
	end
end

local function countOwned(player: Player, snackrotName: string): number
	local owned = GameState.getOwnedSnackrots(player)
	local entry = owned[snackrotName]
	if entry then
		return entry.count
	end
	return 0
end

-- canRebirth: both requirements are checked in one place, and the reason is bilingual.
local function canRebirth(player: Player): (boolean, string)
	local tier = GameState.getRebirthTier(player)
	local nextTier = tier + 1
	local tierData = Config.getRebirthTier(nextTier)

	if not tierData then
		return false, "Max rebirth reached / Rebirth maksimal tercapai"
	end

	if GameState.getCash(player) < tierData.cashRequired then
		local missing = tierData.cashRequired - GameState.getCash(player)
		return false, "Need " .. SnackrotLabel.formatMoney(missing) .. " more / Butuh " .. SnackrotLabel.formatMoney(missing) .. " lagi"
	end

	if countOwned(player, tierData.snackrotRequired) < 1 then
		return false, "Need " .. tierData.snackrotRequired .. " / Butuh " .. tierData.snackrotRequired
	end

	return true, "Ready / Siap"
end

-- doRebirth: wipe the run, keep the multiplier, hand back a bigger warung.
local function doRebirth(player: Player): (boolean, string)
	local ready, reason = canRebirth(player)
	if not ready then
		notifyPlayer(player, reason, "bad")
		return false, reason
	end

	local nextTier = GameState.getRebirthTier(player) + 1
	local tierData = Config.getRebirthTier(nextTier)
	if not tierData then
		return false, "Max rebirth reached / Rebirth maksimal tercapai"
	end

	GameState.resetPlayerState(player)
	GameState.setRebirthTier(player, nextTier)

	local newSlots = Config.getMaxSlots(nextTier)
	local state = GameState.getState(player)
	state.slotsUnlocked = newSlots

	local lockDuration = Config.getLockDuration(nextTier)
	GameState.setLockUntil(player, os.time() + lockDuration)
	GameState.recalculateIncome(player)

	Base.onRebirth(player, nextTier)

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayName = player.Name .. " [R" .. nextTier .. "]"
		end
		JuiceFX.celebrateRebirth(character)
	end

	fireBanner(player, "REBIRTH " .. nextTier .. "!", "LAHIR ULANG " .. nextTier .. "!  x" .. tierData.multiplier .. " income", 5)
	notifyPlayer(player, "Slots " .. newSlots .. " / Slot " .. newSlots .. ", lock " .. lockDuration .. "s", "gold")

	return true, "Rebirth " .. nextTier
end

local function getRebirthInfo(player: Player): { [string]: any }
	local tier = GameState.getRebirthTier(player)
	local nextTier = tier + 1
	local tierData = Config.getRebirthTier(nextTier)
	local ready, reason = canRebirth(player)
	local current = Config.getRebirthTier(tier)

	local info = {
		tier = tier,
		maxTier = Config.CONFIG.rebirthMaxTier,
		canRebirth = ready,
		reason = reason,
		incomeMultiplier = Config.getIncomeMultiplier(tier),
		slots = GameState.getSlotCount(player),
		nextTier = nextTier,
		cashRequired = 0,
		snackrotRequired = "",
		nextMultiplier = 0,
	}

	if tierData then
		info.cashRequired = tierData.cashRequired
		info.snackrotRequired = tierData.snackrotRequired
		info.nextMultiplier = tierData.multiplier
	end
	if current then
		info.currentMultiplier = current.multiplier
	end

	return info
end

-- The wall of tiers the client prints in the rebirth panel.
local function getAllRebirthTiersInfo(): { { [string]: any } }
	local list = {}
	for index, tierData in Config.getAllRebirthTiers() do
		table.insert(list, {
			tier = index,
			cashRequired = tierData.cashRequired,
			snackrotRequired = tierData.snackrotRequired,
			multiplier = tierData.multiplier,
			slotsBonus = tierData.slotsBonus,
			lockBonus = tierData.lockBonus,
		})
	end
	return list
end

return {
	canRebirth = canRebirth,
	doRebirth = doRebirth,
	getRebirthInfo = getRebirthInfo,
	getAllRebirthTiersInfo = getAllRebirthTiersInfo,
}
