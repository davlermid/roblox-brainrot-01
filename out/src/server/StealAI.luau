-- src/server/StealAI.luau
-- Thief NPC "Tukang Parkir Liar" + defences (lock/dog/slap).

local GameState = require(script.Parent.GameState)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Economy = require(script.Parent.Economy)
local Base = require(script.Parent.Base)

local thievesFolder = workspace:FindFirstChild("Thieves") or Instance.new("Folder", workspace)
thievesFolder.Name = "Thieves"

local activeThieves: { [Model]: { targetPlayer: Player, targetSlot: number, state: string, slapCount: number } } = {}
local thiefSpawnConnections: { RBXScriptConnection } = {}

-- Forward declarations: these two are used by closures created above their definitions.
local slapThief
local onThiefReachedBase

local function banner(player: Player, title: string, subtitle: string, duration: number)
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if not remotes then return end
	local remote = remotes:FindFirstChild("BannerEvent")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, title, subtitle, duration)
	end
end

local function notify(player: Player, message: string, kind: string)
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if not remotes then return end
	local remote = remotes:FindFirstChild("NotificationEvent")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, message, kind)
	end
end

local function createThief(targetPlayer: Player): Model?
	if GameState.isBaseLocked(targetPlayer) then return nil end
	
	local state = GameState.getState(targetPlayer)
	if not next(state.equippedSnackrots) then return nil end
	
	-- Find most valuable snackrot
	local mostValuable = ""
	local highestValue = 0
	local targetSlot = 0
	
	for slotIndex, snackrotName in state.equippedSnackrots do
		if snackrotName then
			local snackrot = require(game:GetService("ReplicatedStorage").Shared.SnackrotDB).getSnackrotByName(snackrotName)
			if snackrot and snackrot.cost > highestValue then
				highestValue = snackrot.cost
				mostValuable = snackrotName
				targetSlot = slotIndex
			end
		end
	end
	
	if mostValuable == "" then return nil end
	
	-- Check for Anjing Penjaga / guard dog
	if Economy.hasGuardDog(targetPlayer) then
		-- 50% chance the dog chases the thief away before it touches the base
		if math.random() < 0.5 then
			banner(targetPlayer, "DOG SAVED YOUR BASE!", "ANJING PENJAGA MENGUSIR PENCURI!", 3)
			return nil
		end
	end
	
	-- Create thief model
	local thief = Instance.new("Model")
	thief.Name = "TukangParkirLiar"
	thief.Parent = thievesFolder
	
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 16
	humanoid.Parent = thief
	
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Massless = false
	rootPart.Position = Vector3.new(100, 5, 100) -- Spawn at map edge
	rootPart.Parent = thief
	
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Anchored = false
	torso.CanCollide = true
	torso.Massless = false
	torso.Color = Color3.fromRGB(100, 50, 30)
	torso.Parent = thief
	
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = torso
	weld.Parent = rootPart
	
	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Anchored = false
	head.CanCollide = true
	head.Massless = false
	head.Color = Color3.fromRGB(255, 200, 150)
	head.Parent = thief
	
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.C0 = CFrame.new(0, 1.5, 0)
	headWeld.Parent = torso
	
	-- Name tag
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ThiefTag"
	billboard.Size = UDim2.new(9, 0, 2.4, 0)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "TUKANG PARKIR LIAR\nTHIEF / PENCURI — click to slap / klik untuk tampar"
	textLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.Parent = billboard

	-- Click detector for slapping
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 15
	clickDetector.Parent = rootPart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Slap / Tampar"
	prompt.ObjectText = "Tukang Parkir Liar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = rootPart
	prompt.Triggered:Connect(function(player)
		slapThief(player, thief)
	end)
	
	clickDetector.MouseClick:Connect(function(player)
		slapThief(player, thief)
	end)
	
	activeThieves[thief] = {
		targetPlayer = targetPlayer,
		targetSlot = targetSlot,
		targetSnackrot = mostValuable,
		state = "walking_to_base",
		slapCount = 0,
		hasStolen = false,
	}
	
	-- Pathfind to base
	local baseModel = Base.getBaseModel(targetPlayer)
	if baseModel then
		local targetSlotPart = Base.getSlotPart(targetPlayer, targetSlot)
		if targetSlotPart then
			humanoid:MoveTo(targetSlotPart.Position)
		end
	end
	
	return thief
end

function slapThief(player: Player, thief: Model)
	local data = activeThieves[thief]
	if not data or data.targetPlayer ~= player then return end
	if data.state ~= "stealing" and data.state ~= "walking_to_base" then return end
	
	data.slapCount += 1
	
	-- Visual feedback
	local rootPart = thief:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
		particles.Size = NumberSequence.new(1)
		particles.Lifetime = NumberRange.new(0.5)
		particles.Speed = NumberRange.new(5)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = rootPart
		task.delay(1, function() particles:Destroy() end)
	end
	
	if data.slapCount >= 3 then
		-- Thief drops the Snackrot and flees
		data.state = "fleeing"
		local humanoid = thief:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 30
			humanoid:MoveTo(Vector3.new(100, 5, -100)) -- Flee to map edge
		end

		banner(player, "THIEF DROPPED IT!", "PENCURI MENJATUHKAN " .. string.upper(data.targetSnackrot) .. "!", 3)
		
		task.delay(5, function()
			if thief.Parent then
				thief:Destroy()
			end
			activeThieves[thief] = nil
		end)
	end
end

function onThiefReachedBase(thief: Model)
	local data = activeThieves[thief]
	if not data or data.hasStolen then return end
	
	data.state = "stealing"
	data.hasStolen = true
	
	-- Remove the Snackrot from the player's base (owned count, equip slot and visual)
	local targetPlayer = data.targetPlayer
	local stolenName = Base.stealFromBase(targetPlayer, data.targetSlot)
	
	if stolenName then
		-- Thief now carries the snackrot
		data.state = "fleeing"
		local humanoid = thief:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 20
			humanoid:MoveTo(Vector3.new(100, 5, -100)) -- Flee to gate
		end
		
		banner(targetPlayer, "STOLEN! / DICURI!", stolenName .. " taken by Tukang Parkir Liar / dibawa kabur!", 4)
		notify(targetPlayer, "Lock your base / Kunci base-mu — press LOCK", "bad")
		
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		if remotes then
			local flashRemote = remotes:FindFirstChild("ScreenFlash")
			if flashRemote and flashRemote:IsA("RemoteEvent") then
				flashRemote:FireClient(targetPlayer, Color3.fromRGB(255, 40, 40))
			end
		end
	end
		
	task.delay(10, function()
		if thief.Parent then
			thief:Destroy()
		end
		activeThieves[thief] = nil
	end)
end

local function startThiefSpawner()
	for _, conn in thiefSpawnConnections do
		conn:Disconnect()
	end
	table.clear(thiefSpawnConnections)
	
	task.spawn(function()
		while true do
			task.wait(math.random(Config.CONFIG.stealMinInterval, Config.CONFIG.stealMaxInterval))
			
			-- Pick a random player with unlocked base and snackrots
			local candidates = {}
			for _, player in game.Players:GetPlayers() do
				if not GameState.isBaseLocked(player) then
					local state = GameState.getState(player)
					if next(state.equippedSnackrots) then
						table.insert(candidates, player)
					end
				end
			end
			
			if #candidates > 0 then
				local target = candidates[math.random(1, #candidates)]
				createThief(target)
			end
		end
	end)
end

local function stopThiefSpawner()
	for _, conn in thiefSpawnConnections do
		conn:Disconnect()
	end
	table.clear(thiefSpawnConnections)
	
	for thief, _ in activeThieves do
		if thief.Parent then thief:Destroy() end
	end
	table.clear(activeThieves)
end

-- Monitor thief movement
game:GetService("RunService").Heartbeat:Connect(function()
	for thief, data in activeThieves do
		if not thief.Parent then
			activeThieves[thief] = nil
			continue
		end
		
		local humanoid = thief:FindFirstChild("Humanoid")
		local rootPart = thief:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart then continue end
		
		if data.state == "walking_to_base" then
			local baseModel = Base.getBaseModel(data.targetPlayer)
			if baseModel then
				local targetSlotPart = Base.getSlotPart(data.targetPlayer, data.targetSlot)
				if targetSlotPart and (rootPart.Position - targetSlotPart.Position).Magnitude < 5 then
					onThiefReachedBase(thief)
				end
			end
		elseif data.state == "fleeing" then
			-- Check if reached escape point
			if rootPart.Position.X > 90 then
				if thief.Parent then thief:Destroy() end
				activeThieves[thief] = nil
			end
		end
	end
end)

return {
	startThiefSpawner = startThiefSpawner,
	stopThiefSpawner = stopThiefSpawner,
	createThief = createThief,
	slapThief = slapThief,
}