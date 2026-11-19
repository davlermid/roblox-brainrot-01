-- src/shared/SnackrotDB.luau
-- The 12 Snackrot + 5 mutations data (ONLY source of these numbers).

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type MutationType = "Gosong" | "KejuLumer" | "PedasLevel10" | "BekuEsTeh" | "Pelangi"

export type SnackrotData = {
	name: string,
	rarity: Rarity,
	cost: number,
	incomePerSec: number,
	description: string,
	eventOnly: boolean?,
}

export type MutationData = {
	name: MutationType,
	incomeMultiplier: number,
	chance: number, -- percentage out of 100
	visualEffect: string,
	extraEffect: string?,
}

local SNACKROT_DB: { SnackrotData } = {
	{
		name = "Noobini Gorengan",
		rarity = "Common",
		cost = 50,
		incomePerSec = 2,
		description = "Fried banana with legs, paper hat",
	},
	{
		name = "Es Teh Manis Man",
		rarity = "Common",
		cost = 150,
		incomePerSec = 5,
		description = "Iced tea glass with legs, straw antenna",
	},
	{
		name = "Cakwe Panjang Umur",
		rarity = "Rare",
		cost = 600,
		incomePerSec = 14,
		description = "Long curved fried dough, eyes at tip",
	},
	{
		name = "Bakso Beranak",
		rarity = "Rare",
		cost = 1200,
		incomePerSec = 28,
		description = "Meatball bowl, small meatballs hatch inside",
	},
	{
		name = "Siomay Terbang",
		rarity = "Epic",
		cost = 4000,
		incomePerSec = 65,
		description = "Dumpling with banana-leaf wings",
	},
	{
		name = "Nasi Padang Raksasa",
		rarity = "Epic",
		cost = 9000,
		incomePerSec = 130,
		description = "Padang rice packet, rendang as crown",
	},
	{
		name = "Martabak Manis Galau",
		rarity = "Legendary",
		cost = 25000,
		incomePerSec = 320,
		description = "Half-circle sweet martabak, teary eyes",
	},
	{
		name = "Sate Klathak Samurai",
		rarity = "Legendary",
		cost = 60000,
		incomePerSec = 700,
		description = "Satay skewer as katana, glowing embers",
	},
	{
		name = "Gudeg Gundala",
		rarity = "Mythic",
		cost = 150000,
		incomePerSec = 1600,
		description = "Gudeg pot, small lightning above",
	},
	{
		name = "Rendang Raja Rimba",
		rarity = "Mythic",
		cost = 400000,
		incomePerSec = 3800,
		description = "Lion made of rendang, cassava-leaf crown",
	},
	{
		name = "Es Kopi Susu Dewa",
		rarity = "Secret",
		cost = 1200000,
		incomePerSec = 12000,
		description = "Coffee god: golden glass, coffee-steam aura",
	},
	{
		name = "Nasi Goreng Abadi 67",
		rarity = "Secret",
		cost = 5000000,
		incomePerSec = 45000,
		description = "Giant wok with number 67, eternal fire; only during Hujan Emas event",
		eventOnly = true,
	},
}

local MUTATION_DB: { MutationData } = {
	{
		name = "Gosong",
		incomeMultiplier = 2,
		chance = 12,
		visualEffect = "Black color with smoke particles",
	},
	{
		name = "KejuLumer",
		incomeMultiplier = 3,
		chance = 6,
		visualEffect = "Shiny yellow glow",
	},
	{
		name = "PedasLevel10",
		incomeMultiplier = 4,
		chance = 3,
		visualEffect = "Red color with small flame particles",
	},
	{
		name = "BekuEsTeh",
		incomeMultiplier = 4,
		chance = 2,
		visualEffect = "Ice blue color",
		extraEffect = "Slows thieves by 30%",
	},
	{
		name = "Pelangi",
		incomeMultiplier = 5,
		chance = 1,
		visualEffect = "Rotating rainbow colors",
	},
}

local RARITY_COLORS: { [Rarity]: Color3 } = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(0, 120, 255),
	Epic = Color3.fromRGB(180, 0, 255),
	Legendary = Color3.fromRGB(255, 180, 0),
	Mythic = Color3.fromRGB(255, 0, 60),
	Secret = Color3.fromRGB(255, 215, 0),
}

local function getSnackrotByName(name: string): SnackrotData?
	for _, snackrot in SNACKROT_DB do
		if snackrot.name == name then
			return snackrot
		end
	end
	return nil
end

local function getSnackrotByIndex(index: number): SnackrotData?
	return SNACKROT_DB[index]
end

local function getAllSnackrots(): { SnackrotData }
	return SNACKROT_DB
end

local function getMutationByName(name: MutationType): MutationData?
	for _, mutation in MUTATION_DB do
		if mutation.name == name then
			return mutation
		end
	end
	return nil
end

local function getAllMutations(): { MutationData }
	return MUTATION_DB
end

local function rollMutation(): MutationData?
	local roll = math.random(1, 100)
	local cumulative = 0
	for _, mutation in MUTATION_DB do
		cumulative += mutation.chance
		if roll <= cumulative then
			return mutation
		end
	end
	return nil
end

local function getRarityColor(rarity: Rarity): Color3
	return RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
end

return {
	SNACKROT_DB = SNACKROT_DB,
	MUTATION_DB = MUTATION_DB,
	RARITY_COLORS = RARITY_COLORS,
	getSnackrotByName = getSnackrotByName,
	getSnackrotByIndex = getSnackrotByIndex,
	getAllSnackrots = getAllSnackrots,
	getMutationByName = getMutationByName,
	getAllMutations = getAllMutations,
	rollMutation = rollMutation,
	getRarityColor = getRarityColor,
}