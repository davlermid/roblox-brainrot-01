-- src/client/Game.client.luau
-- One job: show the player what the server is doing, and send their intent back.
-- Bilingual by design: every label the player reads has English and Indonesian.
-- The client never changes money. It asks, the server answers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SnackrotDB = require(Shared.SnackrotDB)
local Config = require(Shared.Config)
local SnackrotLabel = require(Shared.SnackrotLabel)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local getStateRemote = remotes:WaitForChild("GetState")
local buySnackrotRemote = remotes:WaitForChild("BuySnackrot")
local sellSnackrotRemote = remotes:WaitForChild("SellSnackrot")
local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade")
local placeOnBaseRemote = remotes:WaitForChild("PlaceSnackrot")
local lockBaseRemote = remotes:WaitForChild("LockBase")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local getRebirthInfoRemote = remotes:WaitForChild("GetRebirthInfo")

local incomeTickRemote = remotes:WaitForChild("IncomeTick")
local bannerRemote = remotes:WaitForChild("BannerEvent")
local notificationRemote = remotes:WaitForChild("NotificationEvent")
local screenFlashRemote = remotes:WaitForChild("ScreenFlash")
local cameraShakeRemote = remotes:WaitForChild("CameraShake")
local rebirthEffectRemote = remotes:WaitForChild("RebirthEffect")

local THEME = {
	bg = Color3.fromRGB(14, 12, 20),
	card = Color3.fromRGB(26, 21, 34),
	cardLight = Color3.fromRGB(38, 31, 50),
	stroke = Color3.fromRGB(255, 196, 60),
	gold = Color3.fromRGB(255, 196, 60),
	green = Color3.fromRGB(96, 232, 148),
	red = Color3.fromRGB(255, 92, 92),
	purple = Color3.fromRGB(190, 120, 255),
	blue = Color3.fromRGB(96, 172, 255),
	text = Color3.fromRGB(246, 241, 252),
	dim = Color3.fromRGB(176, 166, 192),
}

local RARITY_ID = {
	Common = "UMUM",
	Rare = "JARANG",
	Epic = "EPIK",
	Legendary = "LEGENDARIS",
	Mythic = "MITOS",
	Secret = "RAHASIA",
}

local DESC_ID = {
	["Noobini Gorengan"] = "Pisang goreng berkaki, topi kertas",
	["Es Teh Manis Man"] = "Gelas es teh berkaki, sedotan antena",
	["Cakwe Panjang Umur"] = "Cakwe panjang melengkung, mata di ujung",
	["Bakso Beranak"] = "Mangkuk bakso, bakso kecil menetas di dalam",
	["Siomay Terbang"] = "Siomay dengan sayap daun pisang",
	["Nasi Padang Raksasa"] = "Bungkus nasi padang, rendang jadi mahkota",
	["Martabak Manis Galau"] = "Martabak setengah lingkaran, mata berkaca",
	["Sate Klathak Samurai"] = "Tusuk sate jadi katana, bara menyala",
	["Gudeg Gundala"] = "Panci gudeg, petir kecil di atasnya",
	["Rendang Raja Rimba"] = "Singa dari rendang, mahkota daun singkong",
	["Es Kopi Susu Dewa"] = "Dewa kopi: gelas emas, aura uap kopi",
	["Nasi Goreng Abadi 67"] = "Wajan raksasa angka 67, api abadi; hanya saat Hujan Emas",
}

local UPGRADE_DESC_ID = {
	["RunSpeed"] = "+15% kecepatan lari per level",
	["CarryBag"] = "Bawa lebih banyak Snackrot sekaligus (1->3)",
	["GembokWarung"] = "+30 detik durasi kunci base",
	["AnjingPenjaga"] = "Otomatis mengusir 1 pencuri",
}

local SOUNDS = {
	buy = "rbxasset://sounds/electronicpingshort.wav",
	sell = "rbxasset://sounds/switch3.wav",
	error = "rbxasset://sounds/uuhhh.mp3",
	coin = "rbxasset://sounds/electronicpingshort.wav",
	rebirth = "rbxasset://sounds/electronicpingshort.wav",
}

-- Forward declarations: panels are built before these exist, and buttons call them later.
local refreshHUD
local refreshShop
local refreshUpgrades
local refreshRebirth
local showNotification
local showBanner
local showFlash
local playSound
local togglePanel
local requestLock
local requestRebirth
local buyFromShop
local placeFromBag
local sellFromBag

local stateCache = nil
local panelOpen = "none"
local shopRows: { [string]: any } = {}
local upgradeRows: { [string]: any } = {}
local rebirthWidgets: { [string]: any } = {}
local notificationStack: { Frame } = {}
local bannerToken = 0

local function make(className: string, props: { [string]: any }, parent: Instance): Instance
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(gui: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
end

local function addStroke(gui: Instance, color: Color3, thickness: number, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
end

local function newLabel(props: { [string]: any }, parent: Instance): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
	}
	for key, value in props do
		base[key] = value
	end
	return make("TextLabel", base, parent) :: TextLabel
end

local function newButton(text: string, accent: Color3, size: UDim2, position: UDim2, parent: Instance, onClick: () -> ()): TextButton
	local button = make("TextButton", {
		Size = size,
		Position = position,
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.05,
		AutoButtonColor = true,
		Text = text,
		TextColor3 = Color3.fromRGB(18, 14, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		Parent = parent,
	}, parent) :: TextButton
	addCorner(button, 8)
	addStroke(button, Color3.new(1, 1, 1), 1, 0.65)
	button.MouseButton1Click:Connect(onClick)
	return button
end

local function formatRate(income: number): string
	local money = SnackrotLabel.formatMoney(income)
	return "+" .. money .. "/sec • +" .. money .. "/detik"
end

local function formatRarityBi(rarity: string): string
	return string.upper(rarity) .. " / " .. (RARITY_ID[rarity] or string.upper(rarity))
end

local function playSound(name: string)
	local assetId = SOUNDS[name]
	if not assetId then return end
	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume = name == "error" and 1.1 or 0.55
	if name == "rebirth" then
		sound.PlaybackSpeed = 0.85
	end
	sound.Parent = SoundService
	sound:Play()
	task.delay(2, function()
		sound:Destroy()
	end)
end

-- ScreenGui: one root, built once, never rebuilt.
local screenGui = make("ScreenGui", {
	Name = "SnackrotUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
}, playerGui)

-- ============================================================
-- Cash bar (top centre): cash, income, tier, slots, protection
-- ============================================================
local cashCard = make("Frame", {
	Name = "CashCard",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.new(0, 560, 0, 150),
	BackgroundColor3 = THEME.card,
	BackgroundTransparency = 0.12,
	Parent = screenGui,
}, screenGui)
addCorner(cashCard, 14)
addStroke(cashCard, THEME.gold, 2, 0.45)

newLabel({
	Name = "CashCaption",
	Position = UDim2.new(0, 20, 0, 10),
	Size = UDim2.new(0, 200, 0, 18),
	Text = "CASH / UANG",
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.dim,
}, cashCard)

local cashLabel = newLabel({
	Name = "CashValue",
	Position = UDim2.new(0, 18, 0, 28),
	Size = UDim2.new(0, 330, 0, 56),
	Text = "$0",
	TextSize = 46,
	Font = Enum.Font.GothamBlack,
	TextColor3 = THEME.gold,
}, cashCard)

local incomeLabel = newLabel({
	Name = "IncomeValue",
	Position = UDim2.new(0, 20, 0, 84),
	Size = UDim2.new(0, 330, 0, 24),
	Text = "+$0/sec • +$0/detik",
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.green,
}, cashCard)

local chipRow = make("Frame", {
	Name = "Chips",
	Position = UDim2.new(0, 20, 0, 112),
	Size = UDim2.new(1, -40, 0, 26),
	BackgroundTransparency = 1,
	Parent = cashCard,
}, cashCard)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Parent = chipRow,
}, chipRow)

local function newChip(text: string, color: Color3, parent: Instance): TextLabel
	local chip = make("Frame", {
		Size = UDim2.new(0, 0, 0, 24),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.82,
		Parent = parent,
	}, parent)
	addCorner(chip, 6)
	addStroke(chip, color, 1, 0.5)
	local label = newLabel({
		Size = UDim2.new(1, 0, 1, 0),
		Text = text,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.X,
	}, chip)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.Size = UDim2.new(0, 0, 1, 0)
	chip.AutomaticSize = Enum.AutomaticSize.X
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = chip
	return label
end

local tierChip = newChip("R0  •  x1 INCOME / CUAN", THEME.purple, chipRow)
local slotsChip = newChip("SLOT 0/8", THEME.blue, chipRow)
local lockChip = newChip("OPEN / TERBUKA", THEME.gold, chipRow)

-- Objective strip: the whole loop in one line, both languages.
local objectiveStrip = make("Frame", {
	Name = "Objective",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 172),
	Size = UDim2.new(0, 640, 0, 34),
	BackgroundColor3 = THEME.bg,
	BackgroundTransparency = 0.35,
	Parent = screenGui,
}, screenGui)
addCorner(objectiveStrip, 17)
newLabel({
	Size = UDim2.new(1, 0, 1, 0),
	Text = "1 BUY / BELI   >   2 PLACE / TARUH   >   3 PROTECT / JAGA",
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.text,
	TextXAlignment = Enum.TextXAlignment.Center,
}, objectiveStrip)

-- ============================================================
-- Event timers (top right): tsunami and golden rain countdowns
-- ============================================================
local timerCard = make("Frame", {
	Name = "Timers",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 14),
	Size = UDim2.new(0, 300, 0, 156),
	BackgroundColor3 = THEME.card,
	BackgroundTransparency = 0.15,
	Parent = screenGui,
}, screenGui)
addCorner(timerCard, 12)
addStroke(timerCard, THEME.stroke, 1, 0.7)

newLabel({
	Position = UDim2.new(0, 16, 0, 8),
	Size = UDim2.new(1, -32, 0, 18),
	Text = "EVENTS / ACARA",
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.dim,
}, timerCard)

local tsunamiLabel = newLabel({
	Position = UDim2.new(0, 16, 0, 30),
	Size = UDim2.new(1, -32, 0, 22),
	Text = "TSUNAMI 0:00",
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.red,
}, timerCard)

local goldenLabel = newLabel({
	Position = UDim2.new(0, 16, 0, 56),
	Size = UDim2.new(1, -32, 0, 22),
	Text = "GOLDEN RAIN 0:00",
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.gold,
}, timerCard)

local goldenSubLabel = newLabel({
	Position = UDim2.new(0, 16, 0, 78),
	Size = UDim2.new(1, -32, 0, 16),
	Text = "HUJAN EMAS  •  +MUTASI",
	TextSize = 11,
	TextColor3 = Color3.fromRGB(214, 176, 96),
}, timerCard)

local guardLabel = newLabel({
	Position = UDim2.new(0, 16, 0, 98),
	Size = UDim2.new(1, -32, 0, 40),
	Text = "ANJING PENJAGA: OFF\nGUARD DOG: OFF",
	TextSize = 12,
	TextColor3 = THEME.dim,
}, timerCard)

-- ============================================================
-- Action bar (bottom centre)
-- ============================================================
local actionBar = make("Frame", {
	Name = "ActionBar",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -26),
	Size = UDim2.new(0, 900, 0, 62),
	BackgroundTransparency = 1,
	Parent = screenGui,
}, screenGui)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 12),
	Parent = actionBar,
}, actionBar)

local shopButton = newButton("SHOP / TOKO", THEME.gold, UDim2.new(0, 210, 1, 0), UDim2.new(0, 0, 0, 0), actionBar, function()
	togglePanel("shop")
end)
local upgradeButton = newButton("UPGRADE", THEME.blue, UDim2.new(0, 210, 1, 0), UDim2.new(0, 0, 0, 0), actionBar, function()
	togglePanel("upgrade")
end)
local rebirthButton = newButton("REBIRTH / LAHIR ULANG", THEME.purple, UDim2.new(0, 240, 1, 0), UDim2.new(0, 0, 0, 0), actionBar, function()
	togglePanel("rebirth")
end)
local lockButton = newButton("LOCK / KUNCI", THEME.green, UDim2.new(0, 210, 1, 0), UDim2.new(0, 0, 0, 0), actionBar, function()
	requestLock()
end)

newLabel({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -26),
	Size = UDim2.new(0, 460, 0, 40),
	Text = "Move: WASD / geser  •  Buy at the belt: press E / beli di conveyor\nClick a thief to slap / klik pencuri untuk menampar",
	TextSize = 13,
	TextColor3 = THEME.dim,
}, screenGui)

-- ============================================================
-- Panel host
-- ============================================================
local panel = make("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -18, 0.5, 0),
	Size = UDim2.new(0, 660, 0, 700),
	BackgroundColor3 = THEME.card,
	BackgroundTransparency = 0.05,
	Visible = false,
	Parent = screenGui,
}, screenGui)
addCorner(panel, 16)
addStroke(panel, THEME.gold, 2, 0.4)

local panelTitle = newLabel({
	Position = UDim2.new(0, 22, 0, 14),
	Size = UDim2.new(1, -90, 0, 34),
	Text = "SHOP / TOKO",
	TextSize = 26,
	Font = Enum.Font.GothamBlack,
	TextColor3 = THEME.gold,
}, panel)

local panelSubtitle = newLabel({
	Position = UDim2.new(0, 22, 0, 50),
	Size = UDim2.new(1, -40, 0, 20),
	Text = "",
	TextSize = 13,
	TextColor3 = THEME.dim,
}, panel)

local closeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.new(0, 38, 0, 38),
	BackgroundColor3 = THEME.cardLight,
	Text = "X",
	TextColor3 = THEME.text,
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	Parent = panel,
}, panel)
addCorner(closeButton, 8)
closeButton.MouseButton1Click:Connect(function()
	togglePanel(panelOpen)
end)

-- Each tab owns one scrolling body, created on first open and never destroyed.
local panelBodies: { [string]: ScrollingFrame } = {}

local function getPanelBody(key: string): ScrollingFrame
	local existing = panelBodies[key]
	if existing then
		return existing
	end

	local body = make("ScrollingFrame", {
		Name = "Body_" .. key,
		Position = UDim2.new(0, 18, 0, 80),
		Size = UDim2.new(1, -36, 1, -96),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = THEME.gold,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = panel,
	}, panel) :: ScrollingFrame
	make("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	}, body)
	panelBodies[key] = body
	return body
end

local function showPanelBody(key: string): ScrollingFrame
	for name, body in panelBodies do
		body.Visible = name == key
	end
	local body = getPanelBody(key)
	body.Visible = true
	body.CanvasPosition = Vector2.new(0, 0)
	return body
end

-- ============================================================
-- Banner + notifications + flash
-- ============================================================
local bannerFrame = make("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 220),
	Size = UDim2.new(0, 820, 0, 110),
	BackgroundColor3 = THEME.bg,
	BackgroundTransparency = 1,
	Visible = false,
	Parent = screenGui,
}, screenGui)
local bannerTitle = newLabel({
	Size = UDim2.new(1, 0, 0, 58),
	Text = "",
	TextSize = 46,
	Font = Enum.Font.GothamBlack,
	TextColor3 = THEME.gold,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.2,
	TextStrokeColor3 = Color3.new(0, 0, 0),
}, bannerFrame)
local bannerSub = newLabel({
	Position = UDim2.new(0, 0, 0, 58),
	Size = UDim2.new(1, 0, 0, 34),
	Text = "",
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextColor3 = THEME.text,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.3,
	TextStrokeColor3 = Color3.new(0, 0, 0),
}, bannerFrame)

local notifyHolder = make("Frame", {
	Name = "Notifications",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -18, 1, -104),
	Size = UDim2.new(0, 380, 0, 400),
	BackgroundTransparency = 1,
	Parent = screenGui,
}, screenGui)
make("UIListLayout", {
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 6),
	Parent = notifyHolder,
}, notifyHolder)

local flashFrame = make("Frame", {
	Name = "Flash",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = THEME.red,
	BackgroundTransparency = 1,
	ZIndex = 30,
	Parent = screenGui,
}, screenGui)

function showFlash(color: Color3)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 0.15
	TweenService:Create(flashFrame, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

function showNotification(message: string, kind: string?)
	local accent = THEME.blue
	if kind == "good" then
		accent = THEME.green
	elseif kind == "bad" then
		accent = THEME.red
	elseif kind == "gold" then
		accent = THEME.gold
	end

	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.card,
		BackgroundTransparency = 0.08,
		Parent = notifyHolder,
	}, notifyHolder)
	addCorner(frame, 8)
	addStroke(frame, accent, 1, 0.35)

	local label = newLabel({
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 10, 0, 8),
		Text = message,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = THEME.text,
	}, frame)

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = frame

	table.insert(notificationStack, frame)
	if #notificationStack > 4 then
		local oldest = table.remove(notificationStack, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	task.delay(4.5, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.45)
			frame:Destroy()
			for index, item in notificationStack do
				if item == frame then
					table.remove(notificationStack, index)
					break
				end
			end
		end
	end)
end

function showBanner(title: string, subtitle: string, duration: number?)
	bannerToken += 1
	local token = bannerToken
	bannerFrame.Visible = true
	bannerTitle.Text = title
	bannerSub.Text = subtitle or ""
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	bannerTitle.Position = UDim2.new(0, 0, 0, 8)
	bannerSub.Position = UDim2.new(0, 0, 0, 64)

	TweenService:Create(bannerTitle, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }):Play()
	TweenService:Create(bannerSub, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

	task.delay(duration or 3.5, function()
		if token ~= bannerToken then return end
		TweenService:Create(bannerTitle, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(bannerSub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		if token == bannerToken then
			bannerFrame.Visible = false
		end
	end)
end

local function timeText(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local minutes = math.floor(total / 60)
	local rest = total - minutes * 60
	return minutes .. ":" .. string.format("%02d", rest)
end

-- ============================================================
-- Shop panel: 12 Snackrot, prices, income, Buy / Place / Sell
-- ============================================================
local shopBuilt = false

local function buildShopPanel()
	if shopBuilt then return end
	shopBuilt = true
	local body = getPanelBody("shop")

	for index, snackrot in SnackrotDB.getAllSnackrots() do
		local row = make("Frame", {
			Name = "Row_" .. snackrot.name,
			Size = UDim2.new(1, 0, 0, 104),
			BackgroundColor3 = THEME.cardLight,
			BackgroundTransparency = 0.4,
			LayoutOrder = index,
			Parent = body,
		}, body)
		addCorner(row, 10)

		local accent = make("Frame", {
			Size = UDim2.new(0, 6, 0, 88),
			Position = UDim2.new(0, 6, 0, 8),
			BackgroundColor3 = SnackrotDB.getRarityColor(snackrot.rarity),
			BackgroundTransparency = 0,
			Parent = row,
		}, row)
		addCorner(accent, 3)

		local nameLabel = newLabel({
			Position = UDim2.new(0, 20, 0, 4),
			Size = UDim2.new(0, 360, 0, 24),
			Text = snackrot.name,
			TextSize = 19,
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.text,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		local rarityLabel = newLabel({
			Position = UDim2.new(0, 20, 0, 28),
			Size = UDim2.new(0, 360, 0, 16),
			Text = formatRarityBi(snackrot.rarity),
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			TextColor3 = SnackrotDB.getRarityColor(snackrot.rarity),
		}, row)

		local incomeRow = newLabel({
			Position = UDim2.new(0, 20, 0, 46),
			Size = UDim2.new(0, 360, 0, 18),
			Text = "+" .. SnackrotLabel.formatMoney(snackrot.incomePerSec) .. "/sec • +" .. SnackrotLabel.formatMoney(snackrot.incomePerSec) .. "/detik",
			TextSize = 13,
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.green,
		}, row)

		local descEn = newLabel({
			Position = UDim2.new(0, 20, 0, 66),
			Size = UDim2.new(0, 380, 0, 14),
			Text = snackrot.description,
			TextSize = 11,
			TextColor3 = THEME.dim,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		local descId = newLabel({
			Position = UDim2.new(0, 20, 0, 81),
			Size = UDim2.new(0, 380, 0, 14),
			Text = DESC_ID[snackrot.name] or "",
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(146, 136, 164),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		local buyButton = newButton("BUY / BELI  " .. SnackrotLabel.formatMoney(snackrot.cost), THEME.gold, UDim2.new(0, 190, 0, 36), UDim2.new(1, -206, 0, 10), row, function()
			buyFromShop(snackrot.name)
		end)
		buyButton.TextSize = 15

		local placeButton = newButton("PLACE / TARUH", THEME.green, UDim2.new(0, 92, 0, 28), UDim2.new(1, -206, 0, 54), row, function()
			placeFromBag(snackrot.name)
		end)
		placeButton.TextSize = 12

		local sellButton = newButton("SELL / JUAL", THEME.card, UDim2.new(0, 92, 0, 28), UDim2.new(1, -108, 0, 54), row, function()
			sellFromBag(snackrot.name)
		end)
		sellButton.TextColor3 = THEME.text
		sellButton.TextSize = 12
		addStroke(sellButton, THEME.dim, 1, 0.5)

		shopRows[snackrot.name] = {
			row = row,
			buy = buyButton,
			place = placeButton,
			sell = sellButton,
			rarity = rarityLabel,
			descId = descId,
			snackrot = snackrot,
		}
	end
end

function refreshShop()
	if not stateCache then return end
	local owned = stateCache.ownedSnackrots or {}

	for name, widgets in shopRows do
		local entry = owned[name]
		local count = entry and entry.count or 0
		local placed = 0
		for _, equippedName in stateCache.equippedSnackrots or {} do
			if equippedName == name then
				placed += 1
			end
		end

		widgets.buy.Text = "BUY / BELI  " .. SnackrotLabel.formatMoney(widgets.snackrot.cost)
		local affordable = stateCache.cash >= widgets.snackrot.cost
		if affordable then
			widgets.buy.BackgroundColor3 = THEME.gold
			widgets.buy.TextColor3 = Color3.fromRGB(18, 14, 22)
		else
			widgets.buy.BackgroundColor3 = Color3.fromRGB(74, 64, 88)
			widgets.buy.TextColor3 = THEME.dim
		end

		widgets.place.Visible = count > placed
		widgets.sell.Visible = count > placed

		local label = widgets.row:FindFirstChild("OwnedTag")
		if not label then
			label = newLabel({
				Name = "OwnedTag",
				Position = UDim2.new(0, 20, 0, 4),
				Size = UDim2.new(0, 360, 0, 24),
				Text = "",
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				TextColor3 = THEME.gold,
				TextXAlignment = Enum.TextXAlignment.Right,
			}, widgets.row)
		end
		if count > 0 then
			label.Text = "OWNED / DIMILIKI  x" .. count
		else
			label.Text = ""
		end

		if widgets.snackrot.eventOnly then
			widgets.rarity.Text = formatRarityBi(widgets.snackrot.rarity) .. "  •  EVENT ONLY / HANYA EVENT"
		end
	end
end

-- ============================================================
-- Upgrade panel
-- ============================================================
local upgradesBuilt = false

local function buildUpgradePanel()
	if upgradesBuilt then return end
	upgradesBuilt = true
	local body = getPanelBody("upgrade")

	local order = 0
	for _, upgrade in Config.getAllUpgrades() do
		order += 1
		local row = make("Frame", {
			Name = "Upgrade_" .. upgrade.name,
			Size = UDim2.new(1, 0, 0, 96),
			BackgroundColor3 = THEME.cardLight,
			BackgroundTransparency = 0.4,
			LayoutOrder = order,
			Parent = body,
		}, body)
		addCorner(row, 10)

		newLabel({
			Position = UDim2.new(0, 18, 0, 8),
			Size = UDim2.new(0, 400, 0, 22),
			Text = upgrade.name,
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.text,
		}, row)

		newLabel({
			Position = UDim2.new(0, 18, 0, 32),
			Size = UDim2.new(0, 420, 0, 16),
			Text = upgrade.description,
			TextSize = 12,
			TextColor3 = THEME.dim,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		newLabel({
			Position = UDim2.new(0, 18, 0, 46),
			Size = UDim2.new(0, 420, 0, 14),
			Text = UPGRADE_DESC_ID[upgrade.name] or "",
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			TextColor3 = Color3.fromRGB(146, 136, 164),
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		local levelLabel = newLabel({
			Position = UDim2.new(0, 18, 0, 62),
			Size = UDim2.new(0, 300, 0, 22),
			Text = "LEVEL 0",
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.blue,
		}, row)

		local buyButton = newButton("BUY / BELI", THEME.blue, UDim2.new(0, 190, 0, 40), UDim2.new(1, -206, 0, 14), row, function()
			local ok, success, message = pcall(function()
				return buyUpgradeRemote:InvokeServer(upgrade.name)
			end)
			if not ok then
				showNotification("Connection error / Gagal terhubung", "bad")
				return
			end
			if success then
				playSound("buy")
				showNotification(message, "good")
				refreshHUD()
			else
				playSound("error")
				showNotification(message, "bad")
			end
		end)
		buyButton.TextSize = 15

		upgradeRows[upgrade.name] = {
			level = levelLabel,
			buy = buyButton,
			data = upgrade,
		}
	end
end

function refreshUpgrades()
	if not stateCache then return end
	local upgrades = stateCache.upgrades or {}

	for name, widgets in upgradeRows do
		local level = upgrades[name] or 0
		local maxLevel = widgets.data.maxLevel
		widgets.level.Text = "LEVEL " .. level .. " / " .. maxLevel .. "  •  LEVEL " .. level

		if level >= maxLevel then
			widgets.buy.Text = "MAX / MAKSIMAL"
			widgets.buy.BackgroundColor3 = Color3.fromRGB(74, 64, 88)
			widgets.buy.TextColor3 = THEME.dim
		else
			local cost = Config.getUpgradeCost(name, level)
			widgets.buy.Text = "BUY / BELI  " .. SnackrotLabel.formatMoney(cost)
			if stateCache.cash >= cost then
				widgets.buy.BackgroundColor3 = THEME.blue
				widgets.buy.TextColor3 = Color3.fromRGB(18, 14, 22)
			else
				widgets.buy.BackgroundColor3 = Color3.fromRGB(74, 64, 88)
				widgets.buy.TextColor3 = THEME.dim
			end
		end
	end
end

-- ============================================================
-- Rebirth panel
-- ============================================================
local rebirthBuilt = false

local function buildRebirthPanel()
	if rebirthBuilt then return end
	rebirthBuilt = true
	local body = getPanelBody("rebirth")

	local header = newLabel({
		Name = "RebirthHeader",
		Size = UDim2.new(1, 0, 0, 44),
		Text = "R0  >  R1",
		TextSize = 34,
		Font = Enum.Font.GothamBlack,
		TextColor3 = THEME.purple,
		LayoutOrder = 1,
	}, body)

	local multiplier = newLabel({
		Name = "RebirthMultiplier",
		Size = UDim2.new(1, 0, 0, 24),
		Text = "x1.0 income / pendapatan",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = THEME.green,
		LayoutOrder = 2,
	}, body)

	local cashReq = newLabel({
		Name = "RebirthCash",
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextSize = 15,
		LayoutOrder = 3,
	}, body)

	local snackrotReq = newLabel({
		Name = "RebirthSnackrot",
		Size = UDim2.new(1, 0, 0, 24),
		Text = "",
		TextSize = 15,
		LayoutOrder = 4,
	}, body)

	local hint = newLabel({
		Name = "RebirthHint",
		Size = UDim2.new(1, 0, 0, 40),
		Text = "Rebirth resets cash and Snackrot, keeps the multiplier.\nRebirth meriset uang dan Snackrot, multiplier tetap.",
		TextSize = 12,
		TextColor3 = THEME.dim,
		TextWrapped = true,
		LayoutOrder = 5,
	}, body)

	local action = newButton("REBIRTH / LAHIR ULANG", THEME.purple, UDim2.new(1, 0, 0, 52), UDim2.new(0, 0, 0, 0), body, function()
		requestRebirth()
	end)
	action.LayoutOrder = 6

	local listTitle = newLabel({
		Name = "RebirthListTitle",
		Size = UDim2.new(1, 0, 0, 26),
		Text = "TIERS / TINGKAT",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = THEME.gold,
		LayoutOrder = 7,
	}, body)

	rebirthWidgets.header = header
	rebirthWidgets.multiplier = multiplier
	rebirthWidgets.cashReq = cashReq
	rebirthWidgets.snackrotReq = snackrotReq
	rebirthWidgets.action = action
	rebirthWidgets.listTitle = listTitle
	rebirthWidgets.tiers = {}

	for index, tierData in Config.getAllRebirthTiers() do
		local rowText = "R" .. index .. "   " .. SnackrotLabel.formatMoney(tierData.cashRequired) .. "  +  " .. tierData.snackrotRequired .. "   x" .. tierData.multiplier .. "   +" .. tierData.slotsBonus .. " slots / slot"
		local row = newLabel({
			Name = "Tier_" .. index,
			Size = UDim2.new(1, 0, 0, 24),
			Text = rowText,
			TextSize = 13,
			TextColor3 = THEME.text,
			LayoutOrder = 7 + index,
		}, body)
		table.insert(rebirthWidgets.tiers, row)
	end
end

function refreshRebirth()
	if not stateCache then return end
	local ok, payload = pcall(function()
		return getRebirthInfoRemote:InvokeServer()
	end)
	if not ok or type(payload) ~= "table" or not payload.info then
		return
	end
	local info = payload.info

	rebirthWidgets.header.Text = "R" .. info.tier .. "  >  R" .. info.nextTier
	rebirthWidgets.multiplier.Text = "x" .. tostring(info.incomeMultiplier or 1) .. "  >  x" .. tostring(info.nextMultiplier or 1) .. " income / pendapatan"
	rebirthWidgets.cashReq.Text = "Cash / Uang:  " .. SnackrotLabel.formatMoney(stateCache.cash) .. " / " .. SnackrotLabel.formatMoney(info.cashRequired or 0)
	rebirthWidgets.snackrotReq.Text = "Own / Punya:  " .. (info.snackrotRequired ~= "" and info.snackrotRequired or "-")

	local ready = info.canRebirth
	if ready then
		rebirthWidgets.cashReq.TextColor3 = THEME.green
		rebirthWidgets.snackrotReq.TextColor3 = THEME.green
		rebirthWidgets.action.BackgroundColor3 = THEME.purple
		rebirthWidgets.action.TextColor3 = Color3.fromRGB(18, 14, 22)
		rebirthWidgets.action.Text = "REBIRTH / LAHIR ULANG"
	else
		rebirthWidgets.cashReq.TextColor3 = THEME.red
		rebirthWidgets.snackrotReq.TextColor3 = THEME.red
		rebirthWidgets.action.BackgroundColor3 = Color3.fromRGB(74, 64, 88)
		rebirthWidgets.action.TextColor3 = THEME.dim
		rebirthWidgets.action.Text = "NOT READY / BELUM BISA"
	end
	rebirthWidgets.listTitle.Text = "TIERS / TINGKAT  —  " .. (info.reason or "")
end

-- ============================================================
-- HUD refresh: the whole player-facing truth, once per poll
-- ============================================================
local lastIncomeShown = -1

function refreshHUD()
	if not stateCache then return end
	local state = stateCache

	cashLabel.Text = SnackrotLabel.formatMoney(state.cash or 0)
	incomeLabel.Text = formatRate(state.totalIncomePerSec or 0)

	if state.totalIncomePerSec and state.totalIncomePerSec ~= lastIncomeShown and lastIncomeShown >= 0 then
		local difference = state.totalIncomePerSec - lastIncomeShown
		if difference > 0 then
			local pop = newLabel({
				Position = UDim2.new(0, 340, 0, 34),
				Size = UDim2.new(0, 200, 0, 28),
				Text = "+" .. SnackrotLabel.formatMoney(difference) .. "/s",
				TextSize = 18,
				Font = Enum.Font.GothamBlack,
				TextColor3 = THEME.green,
				Parent = cashCard,
			}, cashCard)
			TweenService:Create(pop, TweenInfo.new(0.9), { Position = UDim2.new(0, 340, 0, 6), TextTransparency = 1 }):Play()
			task.delay(1, function()
				pop:Destroy()
			end)
		end
	end
	lastIncomeShown = state.totalIncomePerSec or 0

	local tier = state.rebirthTier or 0
	local multiplier = Config.getIncomeMultiplier(tier)
	tierChip.Text = "R" .. tier .. "  •  x" .. tostring(multiplier) .. " INCOME / CUAN"
	tierChip.TextColor3 = THEME.purple

	local used = 0
	for _ in state.equippedSnackrots or {} do
		used += 1
	end
	slotsChip.Text = "SLOT " .. used .. "/" .. (state.slotsUnlocked or 0)
	slotsChip.TextColor3 = THEME.blue

	local lockSeconds = math.max(0, math.floor(state.lockSeconds or 0))
	if lockSeconds > 0 then
		lockChip.Text = "PROTECTED " .. lockSeconds .. "s / AMAN"
		lockChip.TextColor3 = THEME.green
		lockButton.Text = "LOCKED / TERKUNCI " .. lockSeconds .. "s"
		lockButton.BackgroundColor3 = Color3.fromRGB(48, 92, 62)
		lockButton.TextColor3 = THEME.green
	else
		lockChip.Text = "OPEN / TERBUKA"
		lockChip.TextColor3 = THEME.gold
		lockButton.Text = "LOCK / KUNCI"
		lockButton.BackgroundColor3 = THEME.green
		lockButton.TextColor3 = Color3.fromRGB(18, 14, 22)
	end

	local tsunamiIn = state.tsunamiIn or 0
	if state.tsunamiActive then
		tsunamiLabel.Text = "TSUNAMI NOW! / SEKARANG!"
	else
		tsunamiLabel.Text = "TSUNAMI  " .. timeText(tsunamiIn) .. "  •  GELOMBANG"
	end
	tsunamiLabel.TextColor3 = tsunamiIn < 15 and THEME.red or Color3.fromRGB(255, 140, 140)

	if state.eventActive then
		goldenSubLabel.Text = "HUJAN EMAS  •  MUTASI x3"
		goldenLabel.Text = "GOLDEN RAIN!  " .. timeText(state.eventSecondsLeft or 0)
		goldenLabel.TextColor3 = THEME.gold
	else
		goldenSubLabel.Text = "HUJAN EMAS  •  MUTASI x3"
		goldenLabel.Text = "GOLDEN RAIN  " .. timeText(state.eventIn or 0)
		goldenLabel.TextColor3 = Color3.fromRGB(214, 176, 96)
	end

	local dogText = state.guardDog and "ON / AKTIF" or "OFF / MATI"
	guardLabel.Text = "ANJING PENJAGA: " .. dogText .. "\nGUARD DOG: " .. dogText .. "  •  CARRY " .. tostring(state.carryCapacity or 0) .. "/8"
	guardLabel.TextColor3 = state.guardDog and THEME.green or THEME.dim
end

-- ============================================================
-- Actions: every one of these is a request, never a local change
-- ============================================================
function buyFromShop(snackrotName: string)
	local ok, success, message = pcall(function()
		return buySnackrotRemote:InvokeServer(snackrotName)
	end)
	if not ok then
		showNotification("Connection error / Gagal terhubung", "bad")
		return
	end
	if success then
		playSound("buy")
		showNotification(message or ("Bought " .. snackrotName .. " / Dibeli " .. snackrotName), "good")
	else
		playSound("error")
		showNotification(message or ("Cannot buy / Tidak bisa beli"), "bad")
	end
	refreshHUD()
	refreshShop()
end

function placeFromBag(snackrotName: string)
	if not stateCache then return end
	local slotIndex = nil
	for index = 1, stateCache.slotsUnlocked or 0 do
		if (stateCache.equippedSnackrots or {})[index] == nil then
			slotIndex = index
			break
		end
	end
	if slotIndex == nil then
		playSound("error")
		showNotification("No free slot / Slot penuh", "bad")
		return
	end

	local ok, success, message = pcall(function()
		return placeOnBaseRemote:InvokeServer(slotIndex, snackrotName)
	end)
	if not ok then
		showNotification("Connection error / Gagal terhubung", "bad")
		return
	end
	if success then
		playSound("buy")
		showNotification(message or ("Placed " .. snackrotName .. " / Ditaruh " .. snackrotName), "good")
	else
		playSound("error")
		showNotification(message or "No free slot / Slot penuh", "bad")
	end
	refreshHUD()
	refreshShop()
end

function sellFromBag(snackrotName: string)
	local ok, success, message = pcall(function()
		return sellSnackrotRemote:InvokeServer(snackrotName)
	end)
	if not ok then
		showNotification("Connection error / Gagal terhubung", "bad")
		return
	end
	if success then
		playSound("sell")
		showNotification(message or ("Sold " .. snackrotName .. " / Dijual " .. snackrotName), "good")
	else
		playSound("error")
		showNotification(message or "Cannot sell / Tidak bisa jual", "bad")
	end
	refreshHUD()
	refreshShop()
end

function requestLock()
	local ok, success, seconds = pcall(function()
		return lockBaseRemote:InvokeServer()
	end)
	if not ok then
		showNotification("Connection error / Gagal terhubung", "bad")
		return
	end
	if success then
		playSound("buy")
		showBanner("BASE LOCKED", "BASE AMAN • " .. tostring(seconds or 0) .. "s", 2)
		showNotification("Locked for " .. tostring(seconds or 0) .. "s / Aman " .. tostring(seconds or 0) .. " detik", "good")
	else
		playSound("error")
		showNotification("Cannot lock now / Tidak bisa mengunci", "bad")
	end
	refreshHUD()
end

function requestRebirth()
	local ok, success, message = pcall(function()
		return rebirthRemote:InvokeServer()
	end)
	if not ok then
		showNotification("Connection error / Gagal terhubung", "bad")
		return
	end
	if success then
		local flash = Instance.new("Sound")
		flash.SoundId = SOUNDS.rebirth
		flash.PlaybackSpeed = 0.7
		flash.Volume = 0.8
		flash.Parent = SoundService
		flash:Play()
		task.delay(2, function()
			flash:Destroy()
		end)
		showBanner("REBIRTH!", "LAHIR ULANG! " .. tostring(message or ""), 4)
		showFlash(THEME.purple)
	else
		playSound("error")
		showNotification(message or "Not ready / Belum bisa", "bad")
	end
	refreshHUD()
	refreshRebirth()
end

function togglePanel(name: string)
	if panelOpen == name then
		panelOpen = "none"
		panel.Visible = false
		return
	end

	panelOpen = name
	panel.Visible = true

	if name == "shop" then
		panelTitle.Text = "SHOP / TOKO"
		panelSubtitle.Text = "12 Snackrot  •  Buy, place, sell  /  Beli, taruh, jual"
		buildShopPanel()
		refreshShop()
	elseif name == "upgrade" then
		panelTitle.Text = "UPGRADE"
		panelSubtitle.Text = "Spend cash to earn faster  /  Belanja uang untuk cuan lebih cepat"
		buildUpgradePanel()
		refreshUpgrades()
	elseif name == "rebirth" then
		panelTitle.Text = "REBIRTH / LAHIR ULANG"
		panelSubtitle.Text = "Trade everything for permanent power  /  Tukar semua untuk kekuatan permanen"
		buildRebirthPanel()
		refreshRebirth()
	end

	-- Reveal the body LAST so it is never visible before its content is built.
	showPanelBody(name)
end

-- ============================================================
-- Server -> client events
-- ============================================================
incomeTickRemote.OnClientEvent:Connect(function(cash: number, incomePerSec: number)
	if stateCache then
		stateCache.cash = cash
		stateCache.totalIncomePerSec = incomePerSec
	end
	refreshHUD()
end)

bannerRemote.OnClientEvent:Connect(function(title: string, subtitle: string, duration: number?)
	showBanner(title, subtitle, duration)
end)

notificationRemote.OnClientEvent:Connect(function(message: string, kind: string?)
	showNotification(message, kind)
end)

screenFlashRemote.OnClientEvent:Connect(function(color: Color3?)
	showFlash(color or THEME.red)
end)

cameraShakeRemote.OnClientEvent:Connect(function(intensity: number?)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local strength = intensity or 1
	local startTime = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed > 0.7 then
			camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0)
			if connection then
				connection:Disconnect()
			end
			return
		end
		local fade = 1 - elapsed / 0.7
		camera.CFrame = camera.CFrame * CFrame.new(
			(math.random() - 0.5) * 0.35 * strength * fade,
			(math.random() - 0.5) * 0.35 * strength * fade,
			0
		)
	end)
end)

rebirthEffectRemote.OnClientEvent:Connect(function()
	showFlash(THEME.purple)
	showBanner("REBIRTH!", "LAHIR ULANG!", 3)
	for index = 1, 10 do
		task.delay(index * 0.12, function()
			local spark = newLabel({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(math.random(), 0, 0.55, 0),
				Size = UDim2.new(0, 34, 0, 34),
				Text = "*",
				TextSize = 30,
				Font = Enum.Font.GothamBlack,
				TextColor3 = THEME.gold,
			}, screenGui)
			TweenService:Create(spark, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(spark.Position.X.Scale, 0, 0.2, 0),
				TextTransparency = 1,
			}):Play()
			task.delay(1.4, function()
				spark:Destroy()
			end)
		end)
	end
end)

-- Base slots are clickable on the server (ClickDetector on each slot part):
-- click your own placed Snackrot to lift it back into the bag.

-- ============================================================
-- The poll: one source of truth, refreshed four times a second
-- ============================================================
task.spawn(function()
	while true do
		local ok, result = pcall(function()
			return getStateRemote:InvokeServer()
		end)
		if ok and type(result) == "table" then
			stateCache = result
			refreshHUD()
			if panelOpen == "shop" then
				refreshShop()
			elseif panelOpen == "upgrade" then
				refreshUpgrades()
			elseif panelOpen == "rebirth" then
				refreshRebirth()
			end
		end
		task.wait(0.35)
	end
end)

task.spawn(function()
	task.wait(3)
	showNotification("Buy Snackrot at the belt (press E) / Beli Snackrot di conveyor (tekan E)", "gold")
	task.wait(6)
	showNotification("Place it on your base to earn cash / Taruh di base untuk dapat uang", "good")
	task.wait(7)
	showNotification("Lock your base before the tsunami / Kunci base sebelum tsunami", "bad")
end)
