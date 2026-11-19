-- src/server/WorldBuilder.luau
-- Builds the 3D world (warungs, conveyor, base, sea, safe zones).

local function buildWorld()
	-- Lighting and atmosphere
	local Lighting = game:GetService("Lighting")
	Lighting.ClockTime = 20 -- Night
	Lighting.FogStart = 50
	Lighting.FogEnd = 300
	Lighting.FogColor = Color3.fromRGB(20, 20, 40)
	Lighting.Ambient = Color3.fromRGB(60, 50, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(40, 30, 30)
	Lighting.Brightness = 1.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	
	-- Sky
	local sky = Instance.new("Sky")
	sky.SkyboxBk = "rbxassetid://159454299"
	sky.SkyboxDn = "rbxassetid://159454296"
	sky.SkyboxFt = "rbxassetid://159454293"
	sky.SkyboxLf = "rbxassetid://159454286"
	sky.SkyboxRt = "rbxassetid://159454299"
	sky.SkyboxUp = "rbxassetid://159454300"
	sky.StarCount = 3000
	sky.MoonAngularSize = 10
	sky.Parent = Lighting
	
	-- Terrain: Beach and sea
	local Terrain = workspace:FindFirstChild("Terrain")
	if not Terrain then
		Terrain = Instance.new("Terrain")
		Terrain.Parent = workspace
	end
	
	-- Sand area (plaza)
	Terrain:FillBlock(CFrame.new(0, -2, 0), Vector3.new(200, 4, 200), Enum.Material.Sand)
	
	-- Sea (negative Z)
	Terrain:FillBlock(CFrame.new(0, 5, -150), Vector3.new(300, 50, 300), Enum.Material.Water)
	Terrain.WaterColor = Color3.fromRGB(10, 30, 80)
	Terrain.WaterReflectance = 0.8
	Terrain.WaterTransparency = 0.3
	Terrain.WaterWaveSize = 1
	Terrain.WaterWaveSpeed = 10
	
	-- Central plaza platform
	local plaza = Instance.new("Part")
	plaza.Name = "Plaza"
	plaza.Size = Vector3.new(120, 2, 120)
	plaza.Position = Vector3.new(0, 0, 0)
	plaza.Anchored = true
	plaza.Color = Color3.fromRGB(180, 160, 120)
	plaza.Material = Enum.Material.Concrete
	plaza.Parent = workspace
	
	-- Warungs around plaza (8 warungs in a circle)
	local warungColors = {
		Color3.fromRGB(200, 100, 50),
		Color3.fromRGB(180, 80, 120),
		Color3.fromRGB(100, 180, 80),
		Color3.fromRGB(80, 120, 200),
		Color3.fromRGB(200, 180, 60),
		Color3.fromRGB(180, 60, 180),
		Color3.fromRGB(60, 180, 180),
		Color3.fromRGB(200, 140, 60),
	}
	
	for i = 1, 8 do
		local angle = math.rad(i * 45 - 22.5)
		local radius = 55
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		
		local warung = Instance.new("Model")
		warung.Name = "Warung_" .. i
		warung.Parent = workspace
		
		-- Base
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Size = Vector3.new(14, 4, 10)
		base.Position = Vector3.new(x, 2, z)
		base.Anchored = true
		base.Color = Color3.fromRGB(120, 80, 50)
		base.Material = Enum.Material.Wood
		base.Parent = warung
		
		-- Walls
		for wallIdx = 1, 4 do
			local wall = Instance.new("Part")
			wall.Name = "Wall_" .. wallIdx
			wall.Size = Vector3.new(wallIdx % 2 == 1 and 14 or 1, 6, wallIdx % 2 == 1 and 1 or 10)
			wall.Anchored = true
			wall.Color = warungColors[i]
			wall.Material = Enum.Material.WoodPlanks
			wall.Parent = warung
			
			local wallAngle = angle + (wallIdx - 1) * math.rad(90)
			local wx = x + math.cos(wallAngle) * (wallIdx % 2 == 1 and 0 or 7.5)
			local wz = z + math.sin(wallAngle) * (wallIdx % 2 == 1 and 7.5 or 0)
			wall.Position = Vector3.new(wx, 7, wz)
			wall.CFrame = CFrame.new(wx, 7, wz) * CFrame.Angles(0, wallAngle, 0)
		end
		
		-- Roof (tin)
		local roof = Instance.new("Part")
		roof.Name = "Roof"
		roof.Size = Vector3.new(16, 1, 12)
		roof.Position = Vector3.new(x, 10.5, z)
		roof.Anchored = true
		roof.Color = Color3.fromRGB(100, 100, 120)
		roof.Material = Enum.Material.Metal
		roof.Parent = warung
		
		-- Roof peak
		local roofPeak = Instance.new("WedgePart")
		roofPeak.Name = "RoofPeak"
		roofPeak.Size = Vector3.new(16, 3, 12)
		roofPeak.Position = Vector3.new(x, 13, z)
		roofPeak.Anchored = true
		roofPeak.Color = Color3.fromRGB(100, 100, 120)
		roofPeak.Material = Enum.Material.Metal
		roofPeak.Parent = warung
		
		-- Sign
		local sign = Instance.new("Part")
		sign.Name = "Sign"
		sign.Size = Vector3.new(10, 2, 0.5)
		sign.Position = Vector3.new(x, 14, z + 6)
		sign.Anchored = true
		sign.Color = Color3.fromRGB(255, 255, 100)
		sign.Material = Enum.Material.Neon
		sign.Parent = warung
		
		local signGui = Instance.new("SurfaceGui")
		signGui.Face = Enum.NormalId.Front
		signGui.Parent = sign
		
		local signText = Instance.new("TextLabel")
		signText.Size = UDim2.new(1, 0, 1, 0)
		signText.BackgroundTransparency = 1
		signText.Text = "WARUNG " .. i
		signText.TextColor3 = Color3.new(0, 0, 0)
		signText.TextStrokeTransparency = 0
		signText.TextScaled = true
		signText.Font = Enum.Font.GothamBold
		signText.Parent = signGui
	end
	
	-- Conveyor belt in center
	local conveyorFolder = Instance.new("Folder")
	conveyorFolder.Name = "Conveyor"
	conveyorFolder.Parent = workspace
	
	local beltLength = 80
	local beltWidth = 6
	local beltHeight = 1
	
	-- Belt base
	local beltBase = Instance.new("Part")
	beltBase.Name = "BeltBase"
	beltBase.Size = Vector3.new(beltWidth, beltHeight, beltLength)
	beltBase.Position = Vector3.new(0, 1.5, 0)
	beltBase.Anchored = true
	beltBase.Color = Color3.fromRGB(40, 40, 40)
	beltBase.Material = Enum.Material.Rubber
	beltBase.Parent = conveyorFolder
	
	-- Belt top (moving surface)
	local beltTop = Instance.new("Part")
	beltTop.Name = "BeltTop"
	beltTop.Size = Vector3.new(beltWidth - 1, 0.5, beltLength)
	beltTop.Position = Vector3.new(0, 2.25, 0)
	beltTop.Anchored = true
	beltTop.Color = Color3.fromRGB(60, 60, 60)
	beltTop.Material = Enum.Material.Concrete
	beltTop.Parent = conveyorFolder
	
	-- Rollers
	for i = -beltLength/2, beltLength/2, 8 do
		local roller = Instance.new("Part")
		roller.Name = "Roller"
		roller.Size = Vector3.new(beltWidth + 1, 1, 1)
		roller.Position = Vector3.new(0, 1, i)
		roller.Anchored = true
		roller.Color = Color3.fromRGB(80, 80, 80)
		roller.Material = Enum.Material.Metal
		roller.Shape = Enum.PartType.Cylinder
		roller.Orientation = Vector3.new(0, 0, 90)
		roller.Parent = conveyorFolder
	end
	
	-- Conveyor side rails
	for side = -1, 1, 2 do
		local rail = Instance.new("Part")
		rail.Name = "Rail_" .. (side == -1 and "Left" or "Right")
		rail.Size = Vector3.new(1, 2, beltLength)
		rail.Position = Vector3.new(side * (beltWidth/2 + 0.5), 2.5, 0)
		rail.Anchored = true
		rail.Color = Color3.fromRGB(100, 100, 100)
		rail.Material = Enum.Material.Metal
		rail.Parent = conveyorFolder
	end
	
	-- Spawn point marker
	local spawnMarker = Instance.new("Part")
	spawnMarker.Name = "SpawnMarker"
	spawnMarker.Size = Vector3.new(6, 0.5, 6)
	spawnMarker.Position = Vector3.new(0, 2.5, -beltLength/2 - 3)
	spawnMarker.Anchored = true
	spawnMarker.Transparency = 0.5
	spawnMarker.Color = Color3.fromRGB(0, 255, 100)
	spawnMarker.Material = Enum.Material.Neon
	spawnMarker.CanCollide = false
	spawnMarker.Parent = conveyorFolder
	
	local spawnGui = Instance.new("BillboardGui")
	spawnGui.Size = UDim2.new(4, 0, 1, 0)
	spawnGui.StudsOffset = Vector3.new(0, 3, 0)
	spawnGui.Adornee = spawnMarker
	spawnGui.Parent = spawnMarker
	
	local spawnText = Instance.new("TextLabel")
	spawnText.Size = UDim2.new(1, 0, 1, 0)
	spawnText.BackgroundTransparency = 1
	spawnText.Text = "SNACKROT SPAWN"
	spawnText.TextColor3 = Color3.new(0, 1, 0)
	spawnText.TextStrokeTransparency = 0
	spawnText.TextScaled = true
	spawnText.Font = Enum.Font.GothamBold
	spawnText.Parent = spawnGui
	
	-- Player base area (positive X)
	local baseArea = Instance.new("Part")
	baseArea.Name = "BaseArea"
	baseArea.Size = Vector3.new(60, 1, 60)
	baseArea.Position = Vector3.new(80, 0.5, 0)
	baseArea.Anchored = true
	baseArea.Transparency = 0.5
	baseArea.Color = Color3.fromRGB(100, 200, 100)
	baseArea.Material = Enum.Material.Grass
	baseArea.Parent = workspace
	
	-- Fence around base area
	for side = -1, 1, 2 do
		for _, axis in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)} do
			local fence = Instance.new("Part")
			fence.Name = "Fence"
			fence.Size = axis == Vector3.new(1, 0, 0) and Vector3.new(60, 4, 1) or Vector3.new(1, 4, 60)
			fence.Position = baseArea.Position + axis * 30 * (axis.X == 1 and side or 1) + Vector3.new(0, 2, 0)
			fence.Anchored = true
			fence.Color = Color3.fromRGB(80, 60, 40)
			fence.Material = Enum.Material.Wood
			fence.Parent = workspace
		end
	end
	
	-- Gate
	local gate = Instance.new("Part")
	gate.Name = "Gate"
	gate.Size = Vector3.new(10, 5, 1)
	gate.Position = Vector3.new(50, 2.5, 0)
	gate.Anchored = true
	gate.Color = Color3.fromRGB(180, 150, 100)
	gate.Material = Enum.Material.Wood
	gate.Parent = workspace
	
	local gateGui = Instance.new("BillboardGui")
	gateGui.Size = UDim2.new(6, 0, 2, 0)
	gateGui.StudsOffset = Vector3.new(0, 5, 0)
	gateGui.Adornee = gate
	gateGui.Parent = gate
	
	local gateText = Instance.new("TextLabel")
	gateText.Size = UDim2.new(1, 0, 1, 0)
	gateText.BackgroundTransparency = 1
	gateText.Text = "EXIT GATE"
	gateText.TextColor3 = Color3.new(1, 1, 1)
	gateText.TextStrokeTransparency = 0
	gateText.TextScaled = true
	gateText.Font = Enum.Font.GothamBold
	gateText.Parent = gateGui
	
	-- Path from conveyor to base
	local path = Instance.new("Part")
	path.Name = "Path"
	path.Size = Vector3.new(8, 0.5, 80)
	path.Position = Vector3.new(40, 0.5, 0)
	path.Anchored = true
	path.Color = Color3.fromRGB(160, 140, 100)
	path.Material = Enum.Material.Pavement
	path.Parent = workspace
	
	-- Decorative lanterns along path
	for i = -35, 35, 10 do
		local lantern = Instance.new("Model")
		lantern.Name = "Lantern"
		lantern.Parent = workspace
		
		local pole = Instance.new("Part")
		pole.Name = "Pole"
		pole.Size = Vector3.new(0.5, 8, 0.5)
		pole.Position = Vector3.new(42, 4, i)
		pole.Anchored = true
		pole.Color = Color3.fromRGB(60, 40, 20)
		pole.Material = Enum.Material.Wood
		pole.Parent = lantern
		
		local light = Instance.new("Part")
		light.Name = "Light"
		light.Size = Vector3.new(3, 3, 3)
		light.Position = Vector3.new(42, 8.5, i)
		light.Anchored = true
		light.Color = Color3.fromRGB(255, 200, 100)
		light.Material = Enum.Material.Neon
		light.Shape = Enum.PartType.Ball
		light.Parent = lantern
		
		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.fromRGB(255, 200, 100)
		pointLight.Range = 15
		pointLight.Brightness = 2
		pointLight.Parent = light
	end
	
	-- Market stalls near plaza
	for i = 1, 6 do
		local angle = math.rad(i * 60)
		local radius = 35
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		
		local stall = Instance.new("Model")
		stall.Name = "Stall_" .. i
		stall.Parent = workspace
		
		local table = Instance.new("Part")
		table.Name = "Table"
		table.Size = Vector3.new(8, 1, 4)
		table.Position = Vector3.new(x, 0.5, z)
		table.Anchored = true
		table.Color = Color3.fromRGB(100, 70, 40)
		table.Material = Enum.Material.Wood
		table.Parent = stall
		
		local canopy = Instance.new("Part")
		canopy.Name = "Canopy"
		canopy.Size = Vector3.new(10, 0.5, 6)
		canopy.Position = Vector3.new(x, 4, z)
		canopy.Anchored = true
		canopy.Color = Color3.fromRGB(180, 60, 60)
		canopy.Material = Enum.Material.Fabric
		canopy.Parent = stall
	end
	
	print("World built successfully!")
end

return {
	buildWorld = buildWorld,
}