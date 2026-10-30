-- Race probe (server side). Installed as ServerStorage.RaceProbe in each race window; never part of
-- the agent's project. Observes behaviour only (no knowledge of the implementation's names).
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local Probe = {}

local function player()
	return Players:GetPlayers()[1]
end

local function npcs()
	local list = {}
	for _, h in ipairs(workspace:GetDescendants()) do
		if h:IsA("Humanoid") and h.Health > 0 and not Players:GetPlayerFromCharacter(h.Parent) then
			table.insert(list, h.Parent)
		end
	end
	return list
end

local function stats(p)
	local out = {}
	local ls = p and p:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") then
				out[v.Name] = tonumber(v.Value) or 0
			end
		end
	end
	return out
end

function Probe.observe(duration: number)
	local seen, distances, partCounts = {}, {}, {}
	local npcMax, minHealth, maxHealth = 0, math.huge, 0
	local first, last
	local t0 = os.clock()
	while os.clock() - t0 < duration do
		local p = player()
		local char = p and p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local list = npcs()
		npcMax = math.max(npcMax, #list)
		local sum, n = 0, 0
		for _, m in ipairs(list) do
			seen[m] = true
			local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
			if r and root then
				sum += (r.Position - root.Position).Magnitude
				n += 1
			end
			local c = 0
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then c += 1 end
			end
			table.insert(partCounts, c)
		end
		if n > 0 then table.insert(distances, sum / n) end
		if hum then
			minHealth = math.min(minHealth, hum.Health)
			maxHealth = math.max(maxHealth, hum.MaxHealth)
		end
		local s = stats(p)
		first = first or s
		last = s
		task.wait(0.5)
	end
	local spawned = 0
	for _ in pairs(seen) do spawned += 1 end
	table.sort(partCounts)
	local anchored = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Anchored then anchored += 1 end
	end
	return HttpService:JSONEncode({
		npc_max = npcMax, npc_spawned = spawned,
		dist_first = distances[1], dist_min = (#distances > 0) and math.min(table.unpack(distances)) or nil,
		npc_parts_median = partCounts[math.max(1, math.floor(#partCounts / 2))] or 0,
		health_min = (minHealth ~= math.huge) and minHealth or nil, health_max = maxHealth,
		stats_first = first or {}, stats_last = last or {},
		atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") ~= nil,
		post_effects = #Lighting:GetChildren(),
		anchored_parts = anchored,
		errors = Probe.errors(),
	})
end

function Probe.errors()
	local out = {}
	for _, e in ipairs(game:GetService("LogService"):GetLogHistory()) do
		if e.messageType == Enum.MessageType.MessageError and not string.find(e.message, "rbxassetid://203785492", 1, true) then
			table.insert(out, string.sub(e.message, 1, 160))
		end
	end
	return out
end

function Probe.killPlayer()
	local p = player()
	local hum = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = 0
	end
	return hum ~= nil
end

return Probe
