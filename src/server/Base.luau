-- src/server/Base.luau
-- One job: the player's warung (base). Slots, placing, locking, and losing things.
-- Storytellers: placeOnBase, lockBase, stealFromBase, washAwayBase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SnackrotDB = require(Shared.SnackrotDB)
local Config = require(Shared.Config)
local SnackrotLabel = require(Shared.SnackrotLabel)

local GameState = require(script.Parent.GameState)
local JuiceFX = require(script.Parent.JuiceFX)

local Base = {}

local BASE_AREA_CENTER = Vector3.new(80, 0, 0)
local PLATFORM_SIZE = 12
local SLOT_SPACING = 2.9
local SLOT_COLUMNS = 4
local BASE_GRID_COLUMNS = 3

type BaseRecord = {
	index: number,
	origin: Vector3,
	model: Model,
	slots: { BasePart },
	emptyTags: { [number]: BillboardGui },
	visuals: { [number]: Model },
	sign: BillboardGui?,
	lockRing: Part?,
}

local bases: { [Player]: BaseRecord } = {}
local nextBaseIndex = 0

-- Forward declaration: slot ClickDetectors are created before liftFromBase exists.
local liftFromBase

local function getBasesFolder(): Folder
	local folder = workspace:FindFirstChild("PlayerBases")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PlayerBases"
		folder.Parent = workspace
	end
	return folder :: Folder
end

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

-- Bases are laid out on the grass field at x=80, three per row, so two players never share a plot.
local function computeBaseOrigin(index: number): Vector3
	local column = (index - 1) % BASE_GRID_COLUMNS
	local row = math.floor((index - 1) / BASE_GRID_COLUMNS)
	local x = BASE_AREA_CENTER.X + (column - 1) * 15
	local z = BASE_AREA_CENTER.Z - 14 + (row % 2) * 28
	return Vector3.new(x, 1.5, z)
end

local function computeSlotOffset(slotIndex: number, totalSlots: number): Vector3
	local columns = math.min(SLOT_COLUMNS, math.max(totalSlots, 1))
	local rows = math.ceil(math.max(totalSlots, 1) / SLOT_COLUMNS)
	local column = (slotIndex - 1) % SLOT_COLUMNS
	local row = math.floor((slotIndex - 1) / SLOT_COLUMNS)
	local x = (column - (columns - 1) / 2) * SLOT_SPACING
	local z = (row - (rows - 1) / 2) * SLOT_SPACING
	return Vector3.new(x, 0.2, z)
end

local function getSlotPart(record: BaseRecord, slotIndex: number): BasePart?
	return record.slots[slotIndex]
end

local function refreshSlotTag(player: Player, record: BaseRecord, slotIndex: number, snackrotName: string?)
	local slotPart = record.slots[slotIndex]
	if not slotPart then return end

	local oldTag = slotPart:FindFirstChild("SlotTag")
	if oldTag then
		oldTag:Destroy()
	end

	if snackrotName then
		record.emptyTags[slotIndex] = nil
		return
	end

	local tag = SnackrotLabel.createEmptySlotLabel(slotIndex)
	tag.Adornee = slotPart
	tag.Parent = slotPart
	record.emptyTags[slotIndex] = tag
end

local function paintSlot(part: BasePart, isEmpty: boolean)
	if isEmpty then
		part.Color = Color3.fromRGB(90, 120, 95)
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0.35
	else
		part.Color = Color3.fromRGB(120, 200, 130)
		part.Material = Enum.Material.Neon
		part.Transparency = 0.15
	end
end

local function syncSlotCount(player: Player, record: BaseRecord)
	local wanted = GameState.getSlotCount(player)

	for slotIndex = 1, wanted do
		if not record.slots[slotIndex] then
			local slotPart = Instance.new("Part")
			slotPart.Name = "Slot" .. slotIndex
			slotPart.Size = Vector3.new(2.4, 0.25, 2.4)
			slotPart.Anchored = true
			slotPart.CanCollide = false
			slotPart.Position = record.origin + computeSlotOffset(slotIndex, wanted)
			slotPart.Parent = record.model
			slotPart:SetAttribute("SlotIndex", slotIndex)

			-- Click your own placed Snackrot to lift it back into the bag.
			local clickDetector = Instance.new("ClickDetector")
			clickDetector.Name = "SlotClick"
			clickDetector.MaxActivationDistance = 16
			clickDetector.Parent = slotPart
			clickDetector.MouseClick:Connect(function(clickingPlayer)
				if clickingPlayer == player then
					liftFromBase(player, slotIndex)
				end
			end)

			record.slots[slotIndex] = slotPart
			paintSlot(slotPart, true)
			refreshSlotTag(player, record, slotIndex, nil)
		end
	end

	for slotIndex, slotPart in record.slots do
		if slotIndex > wanted then
			slotPart:Destroy()
			record.slots[slotIndex] = nil
		end
	end
end

local function refreshBaseSign(player: Player, record: BaseRecord)
	if not record.sign then return end
	local isLocked = GameState.isBaseLocked(player)
	local secondsLeft = math.max(0, GameState.getLockUntil(player) - os.time())
	SnackrotLabel.updateBaseSign(record.sign, isLocked, secondsLeft)

	if record.lockRing then
		record.lockRing.Transparency = isLocked and 0.55 or 1
	end
end

local function createBaseForPlayer(player: Player): BaseRecord
	if bases[player] then
		return bases[player]
	end

	nextBaseIndex += 1
	local index = nextBaseIndex
	local origin = computeBaseOrigin(index)

	local model = Instance.new("Model")
	model.Name = "Warung_" .. player.Name
	model.Parent = getBasesFolder()

	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(PLATFORM_SIZE, 1, PLATFORM_SIZE)
	platform.Position = origin
	platform.Anchored = true
	platform.Material = Enum.Material.WoodPlanks
	platform.Color = Color3.fromRGB(120, 80, 50)
	platform.Parent = model
	model.PrimaryPart = platform

	-- Corner posts + canopy so the plot reads as a warung (food stall) from any angle.
	for _, offset in {
		Vector3.new(-PLATFORM_SIZE / 2 + 0.6, 3, -PLATFORM_SIZE / 2 + 0.6),
		Vector3.new(PLATFORM_SIZE / 2 - 0.6, 3, -PLATFORM_SIZE / 2 + 0.6),
		Vector3.new(-PLATFORM_SIZE / 2 + 0.6, 3, PLATFORM_SIZE / 2 - 0.6),
		Vector3.new(PLATFORM_SIZE / 2 - 0.6, 3, PLATFORM_SIZE / 2 - 0.6),
	} do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Size = Vector3.new(0.4, 6, 0.4)
		post.Position = origin + offset
		post.Anchored = true
		post.Color = Color3.fromRGB(90, 60, 40)
		post.Material = Enum.Material.Wood
		post.Parent = model
	end

	local canopy = Instance.new("Part")
	canopy.Name = "Canopy"
	canopy.Size = Vector3.new(PLATFORM_SIZE + 1, 0.3, PLATFORM_SIZE + 1)
	canopy.Position = origin + Vector3.new(0, 6.1, 0)
	canopy.Anchored = true
	canopy.Color = Color3.fromRGB(200, 70, 60)
	canopy.Material = Enum.Material.Fabric
	canopy.Parent = model

	local lockRing = Instance.new("Part")
	lockRing.Name = "LockRing"
	lockRing.Shape = Enum.PartType.Cylinder
	lockRing.Size = Vector3.new(1, PLATFORM_SIZE + 3, PLATFORM_SIZE + 3)
	lockRing.Orientation = Vector3.new(0, 0, 90)
	lockRing.Position = origin + Vector3.new(0, 0.4, 0)
	lockRing.Anchored = true
	lockRing.CanCollide = false
	lockRing.CanQuery = false
	lockRing.Material = Enum.Material.ForceField
	lockRing.Color = Color3.fromRGB(90, 190, 255)
	lockRing.Transparency = 1
	lockRing.Parent = model

	local sign = SnackrotLabel.createBaseSign(player.Name)
	sign.Adornee = platform
	sign.StudsOffset = Vector3.new(0, 7.6, 0)
	sign.Parent = platform

	local record: BaseRecord = {
		index = index,
		origin = origin,
		model = model,
		slots = {},
		emptyTags = {},
		visuals = {},
		sign = sign,
		lockRing = lockRing,
	}

	bases[player] = record
	player:SetAttribute("BaseIndex", index)

	syncSlotCount(player, record)
	refreshBaseSign(player, record)

	return record
end

local function getOrCreateBase(player: Player): BaseRecord
	local record = bases[player]
	if record and record.model.Parent then
		return record
	end
	if record then
		bases[player] = nil
	end
	return createBaseForPlayer(player)
end

local function getBaseModel(player: Player): Model?
	local record = bases[player]
	if record then
		return record.model
	end
	return nil
end

local function getSlotPosition(player: Player, slotIndex: number): Vector3?
	local record = bases[player]
	if not record then return nil end
	local slotPart = record.slots[slotIndex]
	if not slotPart then return nil end
	return slotPart.Position
end

-- Build the physical Snackrot that stands on a slot. Size and colour come from rarity.
local function buildSnackrotVisual(player: Player, record: BaseRecord, slotIndex: number, snackrotName: string, mutationName: string?): Model?
	local slotPart = record.slots[slotIndex]
	local snackrot = SnackrotDB.getSnackrotByName(snackrotName)
	if not slotPart or not snackrot then return nil end

	local oldVisual = record.visuals[slotIndex]
	if oldVisual then
		oldVisual:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = snackrotName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.1, 2.3, 2.1)
	body.Position = slotPart.Position + Vector3.new(0, 1.4, 0)
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.Neon
	body.Color = SnackrotDB.getRarityColor(snackrot.rarity)
	body.Parent = model

	if mutationName then
		body.Material = Enum.Material.Neon
		if mutationName == "Pelangi" then
			body.Color = Color3.fromRGB(255, 120, 220)
		elseif mutationName == "Gosong" then
			body.Color = Color3.fromRGB(70, 55, 45)
			body.Material = Enum.Material.Slate
		elseif mutationName == "KejuLumer" then
			body.Color = Color3.fromRGB(255, 205, 60)
		elseif mutationName == "PedasLevel10" then
			body.Color = Color3.fromRGB(255, 70, 40)
		elseif mutationName == "BekuEsTeh" then
			body.Color = Color3.fromRGB(120, 210, 255)
		end
		JuiceFX.burstOnMutation(body, mutationName)
	end

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Position = body.Position + Vector3.new(0, 1.8, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Color = Color3.fromRGB(255, 240, 220)
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	for _, eyeOffset in { Vector3.new(-0.35, 0.15, 0.7), Vector3.new(0.35, 0.15, 0.7) } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.34, 0.34, 0.34)
		eye.Position = head.Position + eyeOffset
		eye.Anchored = true
		eye.CanCollide = false
		eye.Color = Color3.fromRGB(20, 20, 25)
		eye.Parent = model
	end

	model.PrimaryPart = body

	local tag = SnackrotLabel.createSnackrotLabel(snackrotName, snackrot.rarity, snackrot.incomePerSec, nil, false, mutationName)
	tag.StudsOffset = Vector3.new(0, 6.4, 0)
	SnackrotLabel.attachLabelToModel(model, tag)

	model.Parent = record.model

	local appear = TweenService:Create(body, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = body.Size,
	})
	body.Size = body.Size * 0.4
	appear:Play()

	record.visuals[slotIndex] = model
	return model
end

local function destroyVisual(record: BaseRecord, slotIndex: number)
	local visual = record.visuals[slotIndex]
	if visual then
		visual:Destroy()
		record.visuals[slotIndex] = nil
	end
end

local function pickMutationForName(player: Player, snackrotName: string): string?
	local owned = GameState.getOwnedSnackrots(player)
	local entry = owned[snackrotName]
	if not entry then return nil end

	local bestName = nil
	local bestMultiplier = 0
	for mutationName, count in entry.mutations do
		if count > 0 then
			local mutation = SnackrotDB.getMutationByName(mutationName)
			local multiplier = 1
			if mutation then
				multiplier = mutation.incomeMultiplier
			end
			if multiplier > bestMultiplier then
				bestMultiplier = multiplier
				bestName = mutationName
			end
		end
	end
	return bestName
end

-- placeOnBase: the moment the conveyor purchase becomes income.
local function placeOnBase(player: Player, slotIndex: number, snackrotName: string): (boolean, string)
	local record = getOrCreateBase(player)
	local slotPart = getSlotPart(record, slotIndex)
	if not slotPart then
		return false, "Slot " .. slotIndex .. " not unlocked / Slot belum terbuka"
	end

	if record.visuals[slotIndex] then
		return false, "Slot is taken / Slot sudah terisi"
	end

	local snackrot = SnackrotDB.getSnackrotByName(snackrotName)
	if not snackrot then
		return false, "Unknown Snackrot / Snackrot tidak dikenal"
	end

	if not GameState.equipSnackrot(player, slotIndex, snackrotName) then
		return false, "You do not own this / Kamu belum punya ini"
	end

	local mutationName = pickMutationForName(player, snackrotName)
	buildSnackrotVisual(player, record, slotIndex, snackrotName, mutationName)
	refreshSlotTag(player, record, slotIndex, snackrotName)
	paintSlot(slotPart, false)
	JuiceFX.popOnBuy(record.visuals[slotIndex])

	return true, snackrotName .. " placed on the base / ditaruh di base"
end

-- liftFromBase: put it back in the bag without losing it.
function liftFromBase(player: Player, slotIndex: number): (boolean, string)
	local record = bases[player]
	if not record then
		return false, "No base / Tidak ada base"
	end
	local name = GameState.unequipSnackrot(player, slotIndex)
	if not name then
		return false, "Slot is empty / Slot kosong"
	end
	destroyVisual(record, slotIndex)
	local slotPart = record.slots[slotIndex]
	if slotPart then
		paintSlot(slotPart, true)
	end
	refreshSlotTag(player, record, slotIndex, nil)
	return true, name .. " lifted / diambil"
end

-- stealFromBase: a thief walks in and takes one Snackrot for good.
local function stealFromBase(player: Player, slotIndex: number): (string?, string)
	local record = bases[player]
	if not record then
		return nil, "No base / Tidak ada base"
	end

	if GameState.isBaseLocked(player) then
		return nil, "Locked / Terkunci"
	end

	local name = GameState.unequipSnackrot(player, slotIndex)
	if not name then
		return nil, "Slot is empty / Slot kosong"
	end

	local position = Vector3.new(0, 3, 0)
	local slotPart = record.slots[slotIndex]
	if slotPart then
		position = slotPart.Position
	end

	destroyVisual(record, slotIndex)
	if slotPart then
		paintSlot(slotPart, true)
	end
	refreshSlotTag(player, record, slotIndex, nil)
	GameState.removeOwnedSnackrot(player, name)
	JuiceFX.burstOnSteal(position)

	return name, name .. " was stolen / dicuri!"
end

-- washAwayBase: the tsunami takes the best thing on the base.
local function washAwayBase(player: Player): (string?, string)
	local record = bases[player]
	if not record then
		return nil, "No base / Tidak ada base"
	end

	local victimSlot = nil
	local victimValue = -1
	local victimName = nil

	for slotIndex, name in GameState.getEquippedSnackrots(player) do
		if name then
			local snackrot = SnackrotDB.getSnackrotByName(name)
			if snackrot and snackrot.incomePerSec > victimValue then
				victimValue = snackrot.incomePerSec
				victimSlot = slotIndex
				victimName = name
			end
		end
	end

	if not victimSlot or not victimName then
		return nil, "Nothing to wash away / Tidak ada yang hanyut"
	end

	local position = record.origin
	local slotPart = record.slots[victimSlot]
	if slotPart then
		position = slotPart.Position
	end

	GameState.unequipSnackrot(player, victimSlot)
	destroyVisual(record, victimSlot)
	if slotPart then
		paintSlot(slotPart, true)
	end
	refreshSlotTag(player, record, victimSlot, nil)
	GameState.removeOwnedSnackrot(player, victimName)
	JuiceFX.burstOnSteal(position)

	return victimName, victimName .. " washed away / hanyut!"
end

-- lockBase: spend the timer, buy peace of mind. Thieves bounce off while it runs.
local function lockBase(player: Player): (boolean, number)
	local bonus = GameState.getUpgradeLevel(player, "GembokWarung") * 30
	local duration = Config.getLockDuration(GameState.getRebirthTier(player)) + bonus
	GameState.setLockUntil(player, os.time() + duration)

	local record = bases[player]
	if record then
		refreshBaseSign(player, record)
		if record.lockRing then
			local ring = record.lockRing
			ring.Transparency = 0.75
			ring.Color = Color3.fromRGB(90, 190, 255)
			TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Transparency = 0.55 }):Play()
		end
		if record.sign then
			SnackrotLabel.updateBaseSign(record.sign, true, duration)
		end
		task.spawn(function()
			local deadline = os.time() + duration
			while os.time() < deadline do
				task.wait(1)
				if bases[player] ~= record then
					return
				end
				refreshBaseSign(player, record)
			end
			refreshBaseSign(player, record)
		end)
	end

	notifyPlayer(player, "BASE LOCKED " .. duration .. "s / BASE TERKUNCI " .. duration .. "d", "good")
	return true, duration
end

-- Called by Rebirth after slotsUnlocked grows or by init on respawn.
local function syncBaseToState(player: Player)
	local record = bases[player]
	if not record then
		createBaseForPlayer(player)
		return
	end
	syncSlotCount(player, record)
	refreshBaseSign(player, record)
end

local function onRebirth(player: Player, newTier: number)
	local record = bases[player]
	if not record then
		createBaseForPlayer(player)
		return
	end

	for slotIndex, visual in record.visuals do
		if visual then
			visual:Destroy()
		end
		record.visuals[slotIndex] = nil
	end

	for slotIndex, slotPart in record.slots do
		paintSlot(slotPart, true)
		refreshSlotTag(player, record, slotIndex, nil)
	end

	syncSlotCount(player, record)
	refreshBaseSign(player, record)
	notifyPlayer(player, "Warung rebuilt at tier " .. newTier .. " / Warung dibangun ulang tingkat " .. newTier, "gold")
end

local function removeBaseForPlayer(player: Player)
	local record = bases[player]
	if record then
		record.model:Destroy()
		bases[player] = nil
	end
end

local function getBaseOrigin(player: Player): Vector3?
	local record = bases[player]
	if record then
		return record.origin
	end
	return nil
end

local function getSlotPartForPlayer(player: Player, slotIndex: number): BasePart?
	local record = bases[player]
	if not record then
		return nil
	end
	return getSlotPart(record, slotIndex)
end

return {
	createBaseForPlayer = createBaseForPlayer,
	getOrCreateBase = getOrCreateBase,
	removeBaseForPlayer = removeBaseForPlayer,
	getBaseModel = getBaseModel,
	getBaseOrigin = getBaseOrigin,
	getSlotPosition = getSlotPosition,
	getSlotPart = getSlotPartForPlayer,
	placeOnBase = placeOnBase,
	liftFromBase = liftFromBase,
	stealFromBase = stealFromBase,
	washAwayBase = washAwayBase,
	lockBase = lockBase,
	syncBaseToState = syncBaseToState,
	onRebirth = onRebirth,
	refreshBaseSign = refreshBaseSign,
}
