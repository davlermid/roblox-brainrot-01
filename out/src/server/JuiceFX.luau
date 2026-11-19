-- src/server/JuiceFX.luau
-- One job: the felt response. Every reward and every threat has a particle, a pop or a shake.
-- Names are the game's verbs: popOnBuy, burstOnMutation, glowGoldenRain, splashTsunamiWave, celebrateRebirth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local JuiceFX = {}

local function findRemotes(): Folder?
	return ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
end

local function fireEvent(name: string, ...: any)
	local remotes = findRemotes()
	if not remotes then return end
	local remote = remotes:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(...)
	end
end

-- Small helper: make a part that exists only for the effect, then delete itself.
local function makeEffectPart(parent: Instance, size: Vector3, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- Mutation tint for effects only (the DB holds the numbers; colour is presentation).
local MUTATION_TINT: { [string]: Color3 } = {
	Gosong = Color3.fromRGB(90, 70, 60),
	KejuLumer = Color3.fromRGB(255, 205, 60),
	PedasLevel10 = Color3.fromRGB(255, 60, 30),
	BekuEsTeh = Color3.fromRGB(120, 210, 255),
	Pelangi = Color3.fromRGB(255, 120, 220),
}

local function tintForMutation(mutationName: string?): Color3
	if mutationName and MUTATION_TINT[mutationName] then
		return MUTATION_TINT[mutationName]
	end
	return Color3.fromRGB(180, 120, 255)
end

-- Buy pop: the Snackrot bounces twice and shrinks, so the purchase feels physical.
local function popOnBuy(target: Instance)
	if not target then return end
	local part = nil
	if target:IsA("Model") then
		part = target.PrimaryPart
		if not part then
			part = target:FindFirstChild("Body") :: BasePart?
		end
	elseif target:IsA("BasePart") then
		part = target
	end
	if not part then return end

	task.spawn(function()
		local originalSize = part.Size
		local originalPosition = part.Position
		local originalColor = part.Color

		local upTween = TweenService:Create(part, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = originalSize * 1.22,
			Position = originalPosition + Vector3.new(0, 1.1, 0),
			Color = originalColor:Lerp(Color3.new(1, 1, 1), 0.55),
		})
		upTween:Play()
		upTween.Completed:Wait()

		local downTween = TweenService:Create(part, TweenInfo.new(0.16, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			Size = originalSize,
			Position = originalPosition,
			Color = originalColor,
		})
		downTween:Play()
	end)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 140, 40))
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(5, 9)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(16)
	Debris:AddItem(emitter, 1.4)
end

-- Mutation: a coloured column of light + sparks. Colour comes from the mutation itself.
local function burstOnMutation(target: Instance?, mutationName: string?)
	if not target then return end
	local part: BasePart? = nil
	if target:IsA("Model") then
		part = target.PrimaryPart
	elseif target:IsA("BasePart") then
		part = target
	end
	if not part then return end

	local color = tintForMutation(mutationName)

	local column = makeEffectPart(part.Parent or workspace, Vector3.new(2.4, 18, 2.4), color, 0.55)
	column.Position = part.Position + Vector3.new(0, 9, 0)
	column.Shape = Enum.PartType.Cylinder
	column.Orientation = Vector3.new(0, 0, 90)
	TweenService:Create(column, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(4, 26, 4),
	}):Play()
	Debris:AddItem(column, 1)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.6))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(9, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(40)
	Debris:AddItem(emitter, 1.8)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 6
	light.Range = 22
	light.Parent = part
	TweenService:Create(light, TweenInfo.new(1, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(light, 1.2)
end

-- Steal: a red puff so the loss reads instantly, even at a distance.
local function burstOnSteal(position: Vector3)
	local part = makeEffectPart(workspace, Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(255, 70, 70), 1)
	part.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 90, 70), Color3.fromRGB(120, 20, 20))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = part
	emitter:Emit(24)
	Debris:AddItem(part, 1.4)
end

-- Golden Rain: a sky of falling gold + a warm light sweep. Returns the folder it built so it can be cleaned up.
local function glowGoldenRain(duration: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "GoldenRainFX"
	folder.Parent = workspace

	local rainPart = makeEffectPart(folder, Vector3.new(200, 2, 200), Color3.fromRGB(255, 205, 80), 1)
	rainPart.Position = Vector3.new(0, 90, 0)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 160, 30))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(18, 30)
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Rate = 140
	emitter.Parent = rainPart

	local warmLight = Instance.new("PointLight")
	warmLight.Color = Color3.fromRGB(255, 200, 90)
	warmLight.Brightness = 2.5
	warmLight.Range = 120
	warmLight.Parent = rainPart

	local previousAmbient = Lighting.OutdoorAmbient
	local ambientTween = TweenService:Create(Lighting, TweenInfo.new(1.5), {
		OutdoorAmbient = Color3.fromRGB(150, 120, 60),
	})
	ambientTween:Play()

	task.delay(duration, function()
		if folder.Parent then
			emitter.Rate = 0
			TweenService:Create(rainPart, TweenInfo.new(2), { Transparency = 1 }):Play()
			TweenService:Create(Lighting, TweenInfo.new(2), { OutdoorAmbient = previousAmbient }):Play()
			Debris:AddItem(folder, 3)
		end
	end)

	return folder
end

-- Tsunami: the wave is a wall of neon water with foam, and the camera gets a kick.
local function splashTsunamiWave(wave: BasePart)
	if not wave then return end

	local foam = makeEffectPart(wave, Vector3.new(wave.Size.X, wave.Size.Y * 0.6, 3), Color3.fromRGB(230, 250, 255), 0.35)
	foam.Position = wave.Position + Vector3.new(0, 0, 0)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(240, 255, 255), Color3.fromRGB(120, 190, 255))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(12, 22)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Rate = 0
	emitter.Parent = foam
	emitter:Emit(60)
	Debris:AddItem(foam, 2.2)
end

local function shakeOnTsunami()
	fireEvent("BannerEvent", "TSUNAMI INCOMING!", "TSUNAMI DATANG!", 4)
end

-- Rebirth: your character is lifted, spun and showered in light rays.
local function celebrateRebirth(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local burst = makeEffectPart(workspace, Vector3.new(6, 1, 6), Color3.fromRGB(255, 220, 120), 0.3)
	burst.Shape = Enum.PartType.Cylinder
	burst.Orientation = Vector3.new(0, 0, 90)
	burst.Position = root.Position - Vector3.new(0, 2.4, 0)
	TweenService:Create(burst, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1, 26, 26),
		Transparency = 1,
	}):Play()
	Debris:AddItem(burst, 1.4)

	local rayEmitter = Instance.new("ParticleEmitter")
	rayEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 40))
	rayEmitter.LightEmission = 1
	rayEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	rayEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rayEmitter.Lifetime = NumberRange.new(0.8, 1.6)
	rayEmitter.Speed = NumberRange.new(14, 26)
	rayEmitter.SpreadAngle = Vector2.new(180, 180)
	rayEmitter.Rate = 0
	rayEmitter.Parent = burst
	rayEmitter:Emit(90)
end

return {
	popOnBuy = popOnBuy,
	burstOnMutation = burstOnMutation,
	burstOnSteal = burstOnSteal,
	glowGoldenRain = glowGoldenRain,
	splashTsunamiWave = splashTsunamiWave,
	shakeOnTsunami = shakeOnTsunami,
	celebrateRebirth = celebrateRebirth,
}
