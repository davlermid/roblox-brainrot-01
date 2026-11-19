-- src/server/init.server.luau
-- One job: wiring. Create the remotes, glue the modules together, own the player lifecycle.
-- Every client request lands here first, so the server is the only place money changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local GameState = require(script.GameState)
local Economy = require(script.Economy)
local Spawner = require(script.Spawner)
local Base = require(script.Base)
local StealAI = require(script.StealAI)
local Hazard = require(script.Hazard)
local Rebirth = require(script.Rebirth)
local Events = require(script.Events)
local WorldBuilder = require(script.WorldBuilder)
local JuiceFX = require(script.JuiceFX)

-- Build the 3D world (pasar malam, pantai, warung) before anything looks for it.
WorldBuilder.buildWorld()

-- Remote factory. Functions answer the client, events push to it.
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function createRemote(name: string, className: string): Instance
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local BUY_SNACKROT = createRemote("BuySnackrot", "RemoteFunction")
local SELL_SNACKROT = createRemote("SellSnackrot", "RemoteFunction")
local BUY_UPGRADE = createRemote("BuyUpgrade", "RemoteFunction")
local PLACE_SNACKROT = createRemote("PlaceSnackrot", "RemoteFunction")
local REMOVE_SNACKROT = createRemote("RemoveSnackrot", "RemoteFunction")
local LOCK_BASE = createRemote("LockBase", "RemoteFunction")
local REBIRTH = createRemote("Rebirth", "RemoteFunction")
local GET_REBIRTH_INFO = createRemote("GetRebirthInfo", "RemoteFunction")
local GET_STATE = createRemote("GetState", "RemoteFunction")
local GET_CONVEYOR_ITEMS = createRemote("GetConveyorItems", "RemoteFunction")

local SLAP_THIEF = createRemote("SlapThief", "RemoteEvent")
local INCOME_TICK = createRemote("IncomeTick", "RemoteEvent")
local SNACKROT_PICKED_UP = createRemote("SnackrotPickedUp", "RemoteEvent")
local BANNER_EVENT = createRemote("BannerEvent", "RemoteEvent")
local NOTIFICATION_EVENT = createRemote("NotificationEvent", "RemoteEvent")
local SCREEN_FLASH = createRemote("ScreenFlash", "RemoteEvent")
local PLAY_SOUND = createRemote("PlaySound", "RemoteEvent")
local SET_SKY = createRemote("SetSky", "RemoteEvent")
local CAMERA_SHAKE = createRemote("CameraShake", "RemoteEvent")
local REBIRTH_EFFECT = createRemote("RebirthEffect", "RemoteEvent")
local SNACKROT_BOUGHT = createRemote("SnackrotBought", "RemoteEvent")

-- Guard against a client spamming a RemoteFunction faster than a human can click.
local lastRequestAt: { [Player]: number } = {}

local function throttle(player: Player, minimumInterval: number): boolean
	local now = os.clock()
	local last = lastRequestAt[player] or 0
	if now - last < minimumInterval then
		return true
	end
	lastRequestAt[player] = now
	return false
end

local function safeInvoke(player: Player, handler: () -> any): any
	local ok, result = pcall(handler)
	if not ok then
		warn("[BuySnackrot] request from " .. player.Name .. " failed: " .. tostring(result))
		return false, "Server error / Kesalahan server"
	end
	return result
end

local function describeState(player: Player): { [string]: any }
	local state = GameState.getState(player)
	return {
		cash = state.cash,
		ownedSnackrots = state.ownedSnackrots,
		equippedSnackrots = state.equippedSnackrots,
		slotsUnlocked = state.slotsUnlocked,
		lockUntil = state.lockUntil,
		lockSeconds = math.max(0, state.lockUntil - os.time()),
		rebirthTier = state.rebirthTier,
		upgrades = state.upgrades,
		totalIncomePerSec = state.totalIncomePerSec,
		tsunamiIn = Hazard.getSecondsUntilTsunami(),
		eventIn = Events.getSecondsUntilNextEvent(),
		eventActive = Events.isGoldenRainActive(),
		eventSecondsLeft = Events.getEventTimeLeft(),
		tsunamiActive = Hazard.isTsunamiActive(),
		beltItems = #Spawner.getConveyorItems(),
		carryCapacity = Economy.getCarryCapacity(player),
		guardDog = Economy.hasGuardDog(player),
	}
end

BUY_SNACKROT.OnServerInvoke = function(player: Player, snackrotName: string)
	if type(snackrotName) ~= "string" then
		return false, "Bad request / Permintaan tidak valid"
	end
	if throttle(player, 0.12) then
		return false, "Slow down / Pelan-pelan"
	end
	return safeInvoke(player, function()
		return Economy.buySnackrot(player, snackrotName)
	end)
end

SELL_SNACKROT.OnServerInvoke = function(player: Player, snackrotName: string)
	if type(snackrotName) ~= "string" then
		return false, "Bad request / Permintaan tidak valid"
	end
	if throttle(player, 0.2) then
		return false, "Slow down / Pelan-pelan"
	end
	return safeInvoke(player, function()
		return Economy.sellSnackrot(player, snackrotName)
	end)
end

BUY_UPGRADE.OnServerInvoke = function(player: Player, upgradeName: string)
	if type(upgradeName) ~= "string" then
		return false, "Bad request / Permintaan tidak valid"
	end
	if throttle(player, 0.2) then
		return false, "Slow down / Pelan-pelan"
	end
	return safeInvoke(player, function()
		return Economy.buyUpgrade(player, upgradeName)
	end)
end

PLACE_SNACKROT.OnServerInvoke = function(player: Player, slotIndex: number, snackrotName: string)
	if type(slotIndex) ~= "number" or type(snackrotName) ~= "string" then
		return false, "Bad request / Permintaan tidak valid"
	end
	return safeInvoke(player, function()
		return Base.placeOnBase(player, math.floor(slotIndex), snackrotName)
	end)
end

REMOVE_SNACKROT.OnServerInvoke = function(player: Player, slotIndex: number)
	if type(slotIndex) ~= "number" then
		return false, "Bad request / Permintaan tidak valid"
	end
	return safeInvoke(player, function()
		return Base.liftFromBase(player, math.floor(slotIndex))
	end)
end

LOCK_BASE.OnServerInvoke = function(player: Player)
	if throttle(player, 0.5) then
		return false, 0
	end
	return safeInvoke(player, function()
		return Base.lockBase(player)
	end)
end

REBIRTH.OnServerInvoke = function(player: Player)
	if throttle(player, 1) then
		return false, "Slow down / Pelan-pelan"
	end
	return safeInvoke(player, function()
		return Rebirth.doRebirth(player)
	end)
end

GET_REBIRTH_INFO.OnServerInvoke = function(player: Player)
	return {
		info = Rebirth.getRebirthInfo(player),
		tiers = Rebirth.getAllRebirthTiersInfo(),
		startingCash = Config.CONFIG.startingCash,
	}
end

GET_STATE.OnServerInvoke = function(player: Player)
	return describeState(player)
end

GET_CONVEYOR_ITEMS.OnServerInvoke = function(player: Player)
	local items = {}
	for _, model in Spawner.getConveyorItems() do
		table.insert(items, {
			name = model:GetAttribute("SnackrotName"),
			mutation = model:GetAttribute("MutationName"),
			position = model.PrimaryPart and model.PrimaryPart.Position or Vector3.new(0, 0, 0),
		})
	end
	return items
end

SLAP_THIEF.OnServerEvent:Connect(function(player: Player, thief: Model)
	if thief and thief:IsA("Model") then
		StealAI.slapThief(player, thief)
	end
end)

-- Player lifecycle: one base, one income stream, one welcome message. No duplicate connections.
local function onCharacterAdded(player: Player, character: Model)
	Economy.applyUpgradeEffects(player)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		local tier = GameState.getRebirthTier(player)
		if tier > 0 then
			humanoid.DisplayName = player.Name .. " [R" .. tier .. "]"
		end
	end
end

local function onPlayerAdded(player: Player)
	Base.createBaseForPlayer(player)
	INCOME_TICK:FireClient(player, GameState.getCash(player), GameState.getTotalIncomePerSec(player))

	NOTIFICATION_EVENT:FireClient(player, "Welcome! Buy / Beli -> Place / Taruh -> Earn / Untung", "info")
	BANNER_EVENT:FireClient(player, "STEAL A SNACKROT", "CURI SNACKROT — protect your warung / jaga warungmu", 4)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	lastRequestAt[player] = nil
	Base.removeBaseForPlayer(player)
end)

-- Start the four global systems.
Spawner.startSpawner()
StealAI.startThiefSpawner()
Hazard.startTsunamiCycle()
Events.startEventCycle()
Economy.tickIncome()

print("[STEAL A SNACKROT] Server siap / ready — 12 Snackrot, 5 mutations, 1 tsunami.")

game:BindToClose(function()
	Spawner.stopSpawner()
	StealAI.stopThiefSpawner()
	Hazard.stopTsunamiCycle()
	Events.stopEventCycle()
	Economy.stopTickIncome()
end)
