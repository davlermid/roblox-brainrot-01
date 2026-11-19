-- src/server/Spawner.luau
-- One job: the conveyor. It rolls Snackrot into the world with a price tag and a Buy prompt.
-- Storytellers: spawnSnackrotOnConveyor, buySnackrotFromConveyor, rollMutationWithBonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SnackrotDB = require(Shared.SnackrotDB)
local Config = require(Shared.Config)
local SnackrotLabel = require(Shared.SnackrotLabel)

local Economy = require(script.Parent.Economy)
local JuiceFX = require(script.Parent.JuiceFX)

local Spawner = {}

local CONVEYOR_START_Z = -36
local CONVEYOR_END_Z = 34
local CONVEYOR_Y = 2.6
local BELT_SPEED = 5
local MAX_ON_BELT = 8
local BASE_SPAWN_INTERVAL = 2.8

local RARITY_WEIGHTS = {
	Common = 34,
	Rare = 24,
	Epic = 18,
	Legendary = 13,
	Mythic = 8,
	Secret = 3,
}

local EVENT_SNACKROT_NAME = "Nasi Goreng Abadi 67"
local EVENT_SPAWN_CHANCE = 22

local beltItems: { [Model]: { distance: number, phase: number } } = {}
local spawnRateMultiplier = 1
local goldenRainMode = false
local spawnerRunning = false
local heartbeatConnection: RBXScriptConnection? = nil

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

local function getConveyorFolder(): Folder
	local folder = workspace:FindFirstChild("Conveyor")
	if folder then
		return folder :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = "Conveyor"
	created.Parent = workspace
	return created
end

-- Weighted pick across the six rarities, then a uniform pick inside the rarity band.
local function pickSnackrotByRarity(): any
	local totalWeight = 0
	for _, weight in RARITY_WEIGHTS do
		totalWeight += weight
	end

	local roll = math.random() * totalWeight
	local chosenRarity = "Common"
	local cursor = 0
	for rarity, weight in RARITY_WEIGHTS do
		cursor += weight
		if roll <= cursor then
			chosenRarity = rarity
			break
		end
	end

	local pool = {}
	for _, snackrot in SnackrotDB.getAllSnackrots() do
		if snackrot.rarity == chosenRarity and not snackrot.eventOnly then
			table.insert(pool, snackrot)
		end
	end

	if #pool == 0 then
		return SnackrotDB.getSnackrotByIndex(1)
	end
	return pool[math.random(1, #pool)]
end

-- rollMutationWithBonus: Golden Rain triples the chance, so the belt fills with weird food.
local function rollMutationWithBonus(multiplier: number): any
	local roll = math.random() * 100
	local cumulative = 0
	for _, mutation in SnackrotDB.getAllMutations() do
		cumulative += mutation.chance * multiplier
		if roll <= cumulative then
			return mutation
		end
	end
	return nil
end

local function buildBeltSnackrot(snackrotData, mutationData): Model
	local model = Instance.new("Model")
	model.Name = snackrotData.name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.2, 2.4, 2.2)
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.SmoothPlastic
	body.Color = SnackrotDB.getRarityColor(snackrotData.rarity)
	body.Position = Vector3.new(0, CONVEYOR_Y, CONVEYOR_START_Z)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Anchored = true
	head.CanCollide = false
	head.Color = Color3.fromRGB(255, 235, 210)
	head.Position = body.Position + Vector3.new(0, 1.9, 0)
	head.Parent = model

	for _, eyeOffset in { Vector3.new(-0.38, 0.2, 0.72), Vector3.new(0.38, 0.2, 0.72) } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.36, 0.36, 0.36)
		eye.Anchored = true
		eye.CanCollide = false
		eye.Color = Color3.fromRGB(15, 15, 20)
		eye.Position = head.Position + eyeOffset
		eye.Parent = model
	end

	model.PrimaryPart = body

	local mutationName = nil
	if mutationData then
		mutationName = mutationData.name
		if mutationData.name == "Pelangi" then
			body.Color = Color3.fromRGB(255, 120, 220)
		elseif mutationData.name == "Gosong" then
			body.Color = Color3.fromRGB(70, 55, 45)
		elseif mutationData.name == "KejuLumer" then
			body.Color = Color3.fromRGB(255, 205, 60)
		elseif mutationData.name == "PedasLevel10" then
			body.Color = Color3.fromRGB(255, 70, 40)
		elseif mutationData.name == "BekuEsTeh" then
			body.Color = Color3.fromRGB(120, 210, 255)
		end
	end

	local tag = SnackrotLabel.createSnackrotLabel(
		snackrotData.name,
		snackrotData.rarity,
		snackrotData.incomePerSec,
		snackrotData.cost,
		true,
		mutationName
	)
	SnackrotLabel.attachLabelToModel(model, tag)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy / Beli"
	prompt.ObjectText = snackrotData.name .. " — " .. SnackrotLabel.formatMoney(snackrotData.cost)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	if mutationName then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(body.Color, Color3.fromRGB(255, 255, 255))
		emitter.LightEmission = 0.8
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Lifetime = NumberRange.new(0.4, 0.9)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Rate = 12
		emitter.Parent = body
	end

	return model
end

local function removeBeltItem(model: Model)
	beltItems[model] = nil
	model:Destroy()
end

-- buySnackrotFromConveyor: ProximityPrompt -> server check -> Snackrot changes hands.
local function buySnackrotFromConveyor(player: Player, model: Model)
	if not model or not model.Parent then return end
	if model:GetAttribute("Purchased") then return end

	local snackrotName = model:GetAttribute("SnackrotName")
	local mutationName = model:GetAttribute("MutationName")
	if type(snackrotName) ~= "string" then return end

	model:SetAttribute("Purchased", true)
	local ok, message = Economy.buySnackrot(player, snackrotName, mutationName)
	if not ok then
		model:SetAttribute("Purchased", false)
		notifyPlayer(player, message, "bad")
		return
	end

	JuiceFX.popOnBuy(model)
	if mutationName then
		JuiceFX.burstOnMutation(model.PrimaryPart, mutationName)
	end

	local remotes = getRemotes()
	if remotes then
		local bought = remotes:FindFirstChild("SnackrotBought")
		if bought and bought:IsA("RemoteEvent") then
			bought:FireClient(player, snackrotName, mutationName)
		end
	end

	removeBeltItem(model)
end

local function getConveyorItems(): { Model }
	local list = {}
	for model in beltItems do
		if model.Parent then
			table.insert(list, model)
		else
			beltItems[model] = nil
		end
	end
	return list
end

-- spawnSnackrotOnConveyor: one Snackrot + its price tag appears at the spawn end of the belt.
local function spawnSnackrotOnConveyor(): Model?
	if #getConveyorItems() >= MAX_ON_BELT then
		return nil
	end

	local snackrotData = nil
	if goldenRainMode and math.random(1, 100) <= EVENT_SPAWN_CHANCE then
		snackrotData = SnackrotDB.getSnackrotByName(EVENT_SNACKROT_NAME)
	end
	if not snackrotData then
		snackrotData = pickSnackrotByRarity()
	end
	if not snackrotData then
		return nil
	end

	local mutationMultiplier = 1
	if goldenRainMode then
		mutationMultiplier = Config.CONFIG.eventMutationMultiplier
	end
	local mutationData = rollMutationWithBonus(mutationMultiplier)

	local model = buildBeltSnackrot(snackrotData, mutationData)
	model:SetAttribute("SnackrotName", snackrotData.name)
	if mutationData then
		model:SetAttribute("MutationName", mutationData.name)
	end

	model.Parent = getConveyorFolder()
	beltItems[model] = { distance = 0, phase = math.random() * math.pi * 2 }

	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChild("BuyPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player: Player)
			buySnackrotFromConveyor(player, model)
		end)
	end

	return model
end

local function getConveyorItems(): { Model }
	local list = {}
	for model in beltItems do
		if model.Parent then
			table.insert(list, model)
		else
			beltItems[model] = nil
		end
	end
	return list
end

local function stepConveyor(deltaTime: number)
	local elapsed = os.clock()
	for model, item in beltItems do
		if not model.Parent then
			beltItems[model] = nil
			continue
		end

		item.distance += BELT_SPEED * deltaTime
		if item.distance > (CONVEYOR_END_Z - CONVEYOR_START_Z) then
			removeBeltItem(model)
			continue
		end

		local z = CONVEYOR_START_Z + item.distance
		local bob = math.sin(elapsed * 2 + item.phase) * 0.12
		local target = CFrame.new(Vector3.new(0, CONVEYOR_Y + bob, z)) * CFrame.Angles(0, math.sin(elapsed + item.phase) * 0.15, 0)
		model:PivotTo(target)
	end
end

local function setSpawnRateMultiplier(multiplier: number)
	spawnRateMultiplier = math.max(0.25, multiplier)
end

local function setGoldenRainMode(active: boolean)
	goldenRainMode = active
end

local function startSpawner()
	if spawnerRunning then return end
	spawnerRunning = true

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
	end
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		stepConveyor(deltaTime)
	end)

	task.spawn(function()
		spawnSnackrotOnConveyor()
		while spawnerRunning do
			local interval = BASE_SPAWN_INTERVAL / spawnRateMultiplier
			if goldenRainMode then
				interval = interval * 0.55
			end
			task.wait(interval)
			if spawnerRunning then
				spawnSnackrotOnConveyor()
			end
		end
	end)
end

local function stopSpawner()
	spawnerRunning = false
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	for model in beltItems do
		model:Destroy()
	end
	beltItems = {}
end

return {
	startSpawner = startSpawner,
	stopSpawner = stopSpawner,
	spawnSnackrotOnConveyor = spawnSnackrotOnConveyor,
	buySnackrotFromConveyor = buySnackrotFromConveyor,
	getConveyorItems = getConveyorItems,
	rollMutationWithBonus = rollMutationWithBonus,
	setSpawnRateMultiplier = setSpawnRateMultiplier,
	setGoldenRainMode = setGoldenRainMode,
}
