-- src/server/Events.luau
-- One job: the Golden Rain event. When it runs, mutations and money both get loud.
-- Storytellers: startGoldenRain, endGoldenRain, isGoldenRainActive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Spawner = require(script.Parent.Spawner)
local Economy = require(script.Parent.Economy)
local JuiceFX = require(script.Parent.JuiceFX)

local Events = {}

local goldenRainActive = false
local eventEndsAt = 0
local nextEventAt = os.time() + Config.CONFIG.eventInterval
local eventLoopRunning = false
local rainFolder: Folder? = nil

local function getRemotes(): Folder?
	return ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
end

local function fireBanner(title: string, subtitle: string, duration: number)
	local remotes = getRemotes()
	if not remotes then return end
	local remote = remotes:FindFirstChild("BannerEvent")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(title, subtitle, duration)
	end
end

local function fireGlobalNotification(message: string, kind: string)
	local remotes = getRemotes()
	if not remotes then return end
	local remote = remotes:FindFirstChild("NotificationEvent")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients(message, kind)
	end
end

local endGoldenRain

-- startGoldenRain: 30 seconds of double money, triple mutation odds and a gold sky.
local function startGoldenRain()
	if goldenRainActive then
		return false
	end

	goldenRainActive = true
	local duration = Config.CONFIG.eventDuration
	eventEndsAt = os.time() + duration
	nextEventAt = eventEndsAt + Config.CONFIG.eventInterval

	Spawner.setGoldenRainMode(true)
	Spawner.setSpawnRateMultiplier(2)
	Economy.setEventIncomeMultiplier(2)

	rainFolder = JuiceFX.glowGoldenRain(duration)
	fireBanner("GOLDEN RAIN!", "HUJAN EMAS!  2x cash, 3x mutation", 5)
	fireGlobalNotification("Golden Rain: 2x income / Hujan Emas: 2x pendapatan", "gold")

	task.delay(duration, function()
		endGoldenRain()
	end)

	return true
end

function endGoldenRain()
	if not goldenRainActive then
		return
	end

	goldenRainActive = false
	eventEndsAt = 0

	Spawner.setGoldenRainMode(false)
	Spawner.setSpawnRateMultiplier(1)
	Economy.setEventIncomeMultiplier(1)

	if rainFolder then
		rainFolder = nil
	end

	fireBanner("GOLDEN RAIN OVER", "HUJAN EMAS SELESAI", 3)
end

local function isGoldenRainActive(): boolean
	return goldenRainActive and os.time() < eventEndsAt
end

-- Kept for callers that only care that *an* event is running.
local function isEventActive(): boolean
	return isGoldenRainActive()
end

local function getEventTimeLeft(): number
	if not goldenRainActive then
		return 0
	end
	return math.max(0, eventEndsAt - os.time())
end

local function getSecondsUntilNextEvent(): number
	if goldenRainActive then
		return 0
	end
	return math.max(0, nextEventAt - os.time())
end

local function startEventCycle()
	if eventLoopRunning then
		return
	end
	eventLoopRunning = true

	task.spawn(function()
		while true do
			local waitTime = math.max(5, nextEventAt - os.time())
			task.wait(waitTime)
			if not goldenRainActive then
				startGoldenRain()
			end
			nextEventAt = os.time() + Config.CONFIG.eventInterval
		end
	end)
end

local function stopEventCycle()
	eventLoopRunning = false
	if goldenRainActive then
		endGoldenRain()
	end
end

return {
	startGoldenRain = startGoldenRain,
	triggerGoldenRain = startGoldenRain,
	endGoldenRain = endGoldenRain,
	isGoldenRainActive = isGoldenRainActive,
	isEventActive = isEventActive,
	getEventTimeLeft = getEventTimeLeft,
	getSecondsUntilNextEvent = getSecondsUntilNextEvent,
	startEventCycle = startEventCycle,
	stopEventCycle = stopEventCycle,
}
