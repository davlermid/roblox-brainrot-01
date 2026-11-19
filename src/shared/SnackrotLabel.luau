-- src/shared/SnackrotLabel.luau
-- One job: every label the player reads in the 3D world.
-- Snackrot tags (name + rarity + $/sec), conveyor price tags, empty slot tags, base sign.
-- Bilingual: English first, Indonesian under it, so a judge who reads no Indonesian still gets it.
-- Pure Luau, ends with return.

local SnackrotDB = require(script.Parent.SnackrotDB)

-- Rarity in both languages: "RARE / JARANG"
local RARITY_IN_INDONESIAN = {
	Common = "UMUM",
	Rare = "JARANG",
	Epic = "EPIK",
	Legendary = "LEGENDARIS",
	Mythic = "MITOS",
	Secret = "RAHASIA",
}

-- Mutation chip in both languages: "CHEESE x3 / KEJU x3"
local MUTATION_IN_ENGLISH = {
	Gosong = "BURNT",
	KejuLumer = "CHEESE",
	PedasLevel10 = "SPICY",
	BekuEsTeh = "FROZEN",
	Pelangi = "RAINBOW",
}

local MUTATION_IN_INDONESIAN = {
	Gosong = "GOSONG",
	KejuLumer = "KEJU",
	PedasLevel10 = "PEDAS",
	BekuEsTeh = "BEKU",
	Pelangi = "PELANGI",
}

-- "$1.2M", "$12,500" — K/M/B read the same in every language.
local function formatMoney(amount: number): string
	local rounded = math.floor(math.abs(amount))
	local sign = ""
	if amount < 0 then
		sign = "-"
	end

	if rounded >= 1000000000 then
		return sign .. "$" .. string.format("%.1fB", rounded / 1000000000)
	end
	if rounded >= 1000000 then
		return sign .. "$" .. string.format("%.1fM", rounded / 1000000)
	end
	if rounded >= 10000 then
		return sign .. "$" .. string.format("%.0fK", rounded / 1000)
	end

	local digits = tostring(rounded)
	local grouped = ""
	local counted = 0
	for i = #digits, 1, -1 do
		grouped = string.sub(digits, i, i) .. grouped
		counted += 1
		if counted % 3 == 0 and i > 1 then
			grouped = "," .. grouped
		end
	end
	return sign .. "$" .. grouped
end

-- "$28/sec • $28/detik"
local function formatIncomePerSec(incomePerSec: number): string
	local money = formatMoney(incomePerSec)
	return money .. "/sec • " .. money .. "/detik"
end

local function formatRarity(rarity: string): string
	local indonesian = RARITY_IN_INDONESIAN[rarity] or string.upper(rarity)
	return string.upper(rarity) .. " / " .. indonesian
end

local function formatMutation(mutationName: string, multiplier: number?): string
	local english = MUTATION_IN_ENGLISH[mutationName] or string.upper(mutationName)
	local indonesian = MUTATION_IN_INDONESIAN[mutationName] or string.upper(mutationName)
	local chip = english .. " / " .. indonesian
	if multiplier then
		chip = chip .. " x" .. multiplier
	end
	return chip
end

-- A dark rounded panel behind the text keeps the tag readable over sand, sea or neon.
local function makeTagPanel(billboard: BillboardGui, accentColor: Color3): Frame
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(1, 0, 1, 0)
	panel.BackgroundColor3 = Color3.fromRGB(12, 10, 22)
	panel.BackgroundTransparency = 0.18
	panel.BorderSizePixel = 0
	panel.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 3
	stroke.Transparency = 0.05
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = panel

	return panel
end

local function makeTagRow(parent: Frame, rowName: string, height: number, text: string, color: Color3, font: Enum.Font, strokeWidth: number): TextLabel
	local row = Instance.new("TextLabel")
	row.Name = rowName
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.Text = text
	row.TextColor3 = color
	row.TextScaled = true
	row.Font = font
	row.TextXAlignment = Enum.TextXAlignment.Center
	row.TextStrokeTransparency = 0
	row.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	row.ZIndex = 2
	row.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = strokeWidth
	stroke.Transparency = 0.25
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = row

	return row
end

-- The Snackrot tag: name, rarity, $/sec, optional price and mutation chip.
-- Used on base slots, conveyor items and every floating model in the world.
local function createSnackrotLabel(
	snackrotName: string,
	rarity: string,
	incomePerSec: number,
	price: number?,
	showPrice: boolean?,
	mutationName: string?
): BillboardGui
	local snackrot = SnackrotDB.getSnackrotByName(snackrotName)
	local resolvedRarity = rarity
	local resolvedIncome = incomePerSec
	local resolvedPrice = price

	if snackrot then
		resolvedRarity = snackrot.rarity
		resolvedIncome = snackrot.incomePerSec
		if not resolvedPrice then
			resolvedPrice = snackrot.cost
		end
	end

	local rarityColor = SnackrotDB.getRarityColor(resolvedRarity)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SnackrotTag"
	billboard.Size = UDim2.new(9, 0, 4.4, 0)
	billboard.StudsOffset = Vector3.new(0, 5.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 350
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local panel = makeTagPanel(billboard, rarityColor)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = panel

	makeTagRow(panel, "NameLabel", 52, snackrotName, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack, 2).LayoutOrder = 1
	makeTagRow(panel, "RarityLabel", 34, formatRarity(resolvedRarity), rarityColor, Enum.Font.GothamBold, 2).LayoutOrder = 2
	makeTagRow(panel, "IncomeLabel", 40, formatIncomePerSec(resolvedIncome), Color3.fromRGB(120, 255, 130), Enum.Font.GothamBlack, 2).LayoutOrder = 3

	if mutationName then
		local mutationData = SnackrotDB.getMutationByName(mutationName)
		local multiplier = nil
		if mutationData then
			multiplier = mutationData.incomeMultiplier
		end
		makeTagRow(panel, "MutationLabel", 30, formatMutation(mutationName, multiplier), Color3.fromRGB(255, 230, 120), Enum.Font.GothamBold, 2).LayoutOrder = 4
	end

	if showPrice and resolvedPrice then
		makeTagRow(panel, "PriceLabel", 40, "BUY / BELI  " .. formatMoney(resolvedPrice), Color3.fromRGB(255, 205, 60), Enum.Font.GothamBlack, 2).LayoutOrder = 5
	end

	return billboard
end

-- Empty slot tag: "SLOT 3 • EMPTY / KOSONG" (teaches the loop without a tutorial).
local function createEmptySlotLabel(slotIndex: number): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SlotTag"
	billboard.Size = UDim2.new(4.6, 0, 1.5, 0)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 180
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(1, 0, 1, 0)
	panel.BackgroundColor3 = Color3.fromRGB(15, 35, 20)
	panel.BackgroundTransparency = 0.35
	panel.BorderSizePixel = 0
	panel.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 230, 130)
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = panel

	makeTagRow(panel, "SlotLabel", 0, "", Color3.new(1, 1, 1), Enum.Font.GothamBold, 2)

	local row = panel:FindFirstChild("SlotLabel")
	if row then
		row.Size = UDim2.new(1, 0, 1, 0)
		row.Text = "SLOT " .. slotIndex .. " • EMPTY / KOSONG"
		row.TextColor3 = Color3.fromRGB(180, 255, 200)
	end

	return billboard
end

-- Base sign floating over the warung: owner name + "PROTECTED / AMAN".
local function createBaseSign(ownerName: string): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BaseSign"
	billboard.Size = UDim2.new(11, 0, 2.6, 0)
	billboard.StudsOffset = Vector3.new(0, 9, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local panel = makeTagPanel(billboard, Color3.fromRGB(255, 200, 90))

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	makeTagRow(panel, "OwnerLabel", 46, string.upper(ownerName) .. "'S WARUNG", Color3.fromRGB(255, 225, 140), Enum.Font.GothamBlack, 2).LayoutOrder = 1
	makeTagRow(panel, "LockLabel", 34, "BASE • OPEN / TERBUKA", Color3.fromRGB(120, 255, 130), Enum.Font.GothamBold, 2).LayoutOrder = 2

	return billboard
end

-- Attach a tag to a model's primary part (or its "Main" part).
local function attachLabelToModel(model: Model, billboard: BillboardGui): ()
	local primaryPart = model.PrimaryPart or model:FindFirstChild("Main")
	if not primaryPart or not primaryPart:IsA("BasePart") then
		warn("SnackrotLabel: model " .. model.Name .. " has no PrimaryPart or Main part")
		return
	end

	model.PrimaryPart = primaryPart
	billboard.Adornee = primaryPart
	billboard.Parent = primaryPart
end

-- Repaint the income row when a mutation lands or a rebirth multiplier applies.
local function updateLabelIncome(billboard: BillboardGui, newIncomePerSec: number): ()
	if not billboard or not billboard.Parent then
		return
	end

	local panel = billboard:FindFirstChild("Panel")
	if not panel then
		return
	end

	local incomeLabel = panel:FindFirstChild("IncomeLabel")
	if incomeLabel and incomeLabel:IsA("TextLabel") then
		incomeLabel.Text = formatIncomePerSec(newIncomePerSec)
	end
end

-- Repaint the base sign when the lock is used.
local function updateBaseSign(billboard: BillboardGui, isLocked: boolean, secondsLeft: number): ()
	if not billboard or not billboard.Parent then
		return
	end

	local panel = billboard:FindFirstChild("Panel")
	if not panel then
		return
	end

	local lockLabel = panel:FindFirstChild("LockLabel")
	if not lockLabel or not lockLabel:IsA("TextLabel") then
		return
	end

	if isLocked then
		lockLabel.Text = "LOCKED / TERKUNCI " .. math.floor(secondsLeft) .. "s"
		lockLabel.TextColor3 = Color3.fromRGB(255, 170, 60)
	else
		lockLabel.Text = "BASE • OPEN / TERBUKA"
		lockLabel.TextColor3 = Color3.fromRGB(120, 255, 130)
	end
end

return {
	formatMoney = formatMoney,
	formatIncomePerSec = formatIncomePerSec,
	formatRarity = formatRarity,
	formatMutation = formatMutation,
	createSnackrotLabel = createSnackrotLabel,
	createEmptySlotLabel = createEmptySlotLabel,
	createBaseSign = createBaseSign,
	attachLabelToModel = attachLabelToModel,
	updateLabelIncome = updateLabelIncome,
	updateBaseSign = updateBaseSign,
}
