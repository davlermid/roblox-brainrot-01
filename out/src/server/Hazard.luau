-- src/server/Hazard.luau
-- One job: the tsunami. It warns, it rolls in, and it takes one thing from anyone who did not run.
-- Storytellers: triggerTsunami, isPlayerInSafeZone, buildSafeZones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SnackrotLabel = require(Shared.SnackrotLabel)

local Base = require(script.Parent.Base)
local JuiceFX = require(script.Parent.JuiceFX)

local Hazard = {}

local WAVE_START_Z = 170
local WAVE_END_Z = -70
local WAVE_SPEED = 42
local WAVE_HEIGHT = 26

local SAFE_ZONE_SPOTS = {
	Vector3.new(-22, 0.6, -42),
	Vector3.new(56, 0.6, -28),
	Vector3.new(0, 0.6, 22),
}

local safeZones: { Part } = {}
local tsunamiActive = false
local warningActive = false
local nextTsunamiAt = os.time() + Config.CONFIG.tsunamiInterval
local cycleRunning = false
local hitPlayers: { [Player]: boolean } = {}

local function getRemotes(): Folder?
	return ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
end

local function fireBanner(player: Player?, title: string, subtitle: string, duration: number)
	local remotes = getRemotes()
	if not remotes then return end
	local remote = remotes:FindFirstChild("BannerEvent")
	if not remote or not remote:IsA("RemoteEvent") then return end
	if player then
		remote:FireClient(player, title, subtitle, duration)
	else
		remote:FireAllClients(title, subtitle, duration)
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

-- buildSafeZones: green pads the player can actually reach on foot, labelled in both languages.
local function buildSafeZones()
	local folder = workspace:FindFirstChild("SafeZones")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SafeZones"
		folder.Parent = workspace
	end

	if #safeZones > 0 then
		return safeZones
	end

	for index, spot in SAFE_ZONE_SPOTS do
		local pad = Instance.new("Part")
		pad.Name = "SafeZone" .. index
		pad.Size = Vector3.new(14, 1.2, 14)
		pad.Position = spot
		pad.Anchored = true
		pad.Material = Enum.Material.Neon
		pad.Color = Color3.fromRGB(60, 220, 130)
		pad.Transparency = 0.25
		pad.Parent = folder

		local label = SnackrotLabel.createBaseSign("SAFE ZONE")
		label.Adornee = pad
		label.StudsOffset = Vector3.new(0, 4, 0)
		label.Parent = pad

		local panel = label:FindFirstChild("Panel")
		if panel then
			local owner = panel:FindFirstChild("OwnerLabel")
			local lock = panel:FindFirstChild("LockLabel")
			if owner and owner:IsA("TextLabel") then
				owner.Text = "SAFE ZONE / ZONA AMAN"
				owner.TextColor3 = Color3.fromRGB(120, 255, 160)
			end
			if lock and lock:IsA("TextLabel") then
				lock.Text = "TSUNAMI SHELTER / PERLINDUNGAN"
				lock.TextColor3 = Color3.fromRGB(200, 255, 210)
			end
		end

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(90, 255, 150)
		light.Brightness = 1.6
		light.Range = 18
		light.Parent = pad

		table.insert(safeZones, pad)
	end

	return safeZones
end

local function isPlayerInSafeZone(player: Player): boolean
	local character = player.Character
	if not character then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end

	for _, pad in safeZones do
		local offset = root.Position - pad.Position
		local flatDistance = Vector2.new(offset.X, offset.Z).Magnitude
		if flatDistance <= 8 and math.abs(offset.Y) <= 8 then
			return true
		end
	end
	return false
end

local function buildWave(): Model
	local model = Instance.new("Model")
	model.Name = "TsunamiWave"

	local face = Instance.new("Part")
	face.Name = "Wall"
	face.Size = Vector3.new(230, WAVE_HEIGHT, 10)
	face.Position = Vector3.new(0, WAVE_HEIGHT / 2, WAVE_START_Z)
	face.Anchored = true
	face.CanCollide = false
	face.CanQuery = false
	face.Material = Enum.Material.ForceField
	face.Color = Color3.fromRGB(60, 150, 255)
	face.Transparency = 0.25
	face.Parent = model

	local crest = Instance.new("Part")
	crest.Name = "Crest"
	crest.Size = Vector3.new(230, 3, 12)
	crest.Position = face.Position + Vector3.new(0, WAVE_HEIGHT / 2, 0)
	crest.Anchored = true
	crest.CanCollide = false
	crest.CanQuery = false
	crest.Material = Enum.Material.Neon
	crest.Color = Color3.fromRGB(220, 245, 255)
	crest.Transparency = 0.1
	crest.Parent = model

	local foam = Instance.new("Part")
	foam.Name = "Foam"
	foam.Size = Vector3.new(230, 1.5, 14)
	foam.Position = face.Position - Vector3.new(0, WAVE_HEIGHT / 2 - 1, 0)
	foam.Anchored = true
	foam.CanCollide = false
	foam.CanQuery = false
	foam.Material = Enum.Material.SmoothPlastic
	foam.Color = Color3.fromRGB(235, 250, 255)
	foam.Transparency = 0.35
	foam.Parent = model

	model.PrimaryPart = face
	model:PivotTo(CFrame.new(Vector3.new(0, WAVE_HEIGHT / 2, WAVE_START_Z)))
	return model
end

local function pushPlayer(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(0, 28, -26)
	end
end

local function resolveWaveHit(player: Player, waveZ: number)
	if hitPlayers[player] then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end

	if math.abs(root.Position.Z - waveZ) > 12 then return end
	if math.abs(root.Position.X) > 110 then return end

	if isPlayerInSafeZone(player) then
		if not hitPlayers[player] then
			hitPlayers[player] = true
			notifyPlayer(player, "SAFE from the tsunami / AMAN dari tsunami", "good")
		end
		return
	end

	hitPlayers[player] = true

	local washedName = Base.washAwayBase(player)
	if washedName then
		fireBanner(player, "TSUNAMI!", washedName .. " washed away / hanyut!", 4)
	else
		fireBanner(player, "TSUNAMI!", "Your base is empty / Base-mu kosong", 3)
	end
	pushPlayer(player)
end

-- triggerTsunami: warning first, wave second. Ten seconds is enough to reach a green pad.
local function triggerTsunami()
	if tsunamiActive or warningActive then
		return false
	end
	warningActive = true
	hitPlayers = {}

	buildSafeZones()
	fireBanner(nil, "TSUNAMI WARNING!", "PERINGATAN TSUNAMI — run to a SAFE ZONE / lari ke ZONA AMAN", Config.CONFIG.tsunamiWarningDuration)
	JuiceFX.shakeOnTsunami()

	for _, pad in safeZones do
		TweenService:Create(pad, TweenInfo.new(0.6), { Color = Color3.fromRGB(255, 230, 90) }):Play()
		task.delay(1.2, function()
			if pad.Parent then
				TweenService:Create(pad, TweenInfo.new(0.6), { Color = Color3.fromRGB(60, 220, 130) }):Play()
			end
		end)
	end

	task.delay(Config.CONFIG.tsunamiWarningDuration, function()
		warningActive = false
		tsunamiActive = true
		nextTsunamiAt = os.time() + Config.CONFIG.tsunamiInterval

		local wave = buildWave()
		wave.Parent = workspace
		JuiceFX.splashTsunamiWave(wave.PrimaryPart :: BasePart)

		local flash = Instance.new("ColorCorrectionEffect")
		flash.Parent = Lighting
		flash.TintColor = Color3.fromRGB(150, 210, 255)
		flash.Brightness = 0.1
		TweenService:Create(flash, TweenInfo.new(1.5), { TintColor = Color3.new(1, 1, 1) }):Play()
		Debris:AddItem(flash, 2)

		local z = WAVE_START_Z
		while z > WAVE_END_Z and wave.Parent do
			z -= WAVE_SPEED * 0.05
			wave:PivotTo(CFrame.new(Vector3.new(0, WAVE_HEIGHT / 2, z)))
			for _, player in game.Players:GetPlayers() do
				resolveWaveHit(player, z)
			end
			task.wait(0.05)
		end

		tsunamiActive = false
		hitPlayers = {}
		if wave.Parent then
			for _, part in wave:GetDescendants() do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(1), { Transparency = 1 }):Play()
				end
			end
			Debris:AddItem(wave, 1.2)
		end
	end)

	return true
end

local function startTsunamiCycle()
	if cycleRunning then
		return
	end
	cycleRunning = true
	buildSafeZones()

	task.spawn(function()
		while cycleRunning do
			local waitTime = math.max(5, nextTsunamiAt - os.time())
			task.wait(waitTime)
			if cycleRunning then
				triggerTsunami()
			end
		end
	end)
end

local function stopTsunamiCycle()
	cycleRunning = false
end

local function isTsunamiActive(): boolean
	return tsunamiActive or warningActive
end

local function getSecondsUntilTsunami(): number
	if isTsunamiActive() then
		return 0
	end
	return math.max(0, nextTsunamiAt - os.time())
end

local function getSafeZones(): { Part }
	return safeZones
end

return {
	triggerTsunami = triggerTsunami,
	startTsunamiCycle = startTsunamiCycle,
	stopTsunamiCycle = stopTsunamiCycle,
	buildSafeZones = buildSafeZones,
	isPlayerInSafeZone = isPlayerInSafeZone,
	isTsunamiActive = isTsunamiActive,
	getSecondsUntilTsunami = getSecondsUntilTsunami,
	getSafeZones = getSafeZones,
}
