-- Race probe (client side). Installed as ReplicatedStorage.RaceProbeClient. Observes what the player
-- would see: orbiting non-character parts near the character, visible GUI text, billboards.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Probe = {}

local function visible(gui: Instance): boolean
	local node = gui
	while node and node:IsA("GuiObject") do
		if not node.Visible then return false end
		node = node.Parent
	end
	if node and node:IsA("ScreenGui") and not node.Enabled then return false end
	return true
end

function Probe.observe(duration: number, names: { string }?)
	local lp = Players.LocalPlayer
	local texts, order = {}, {}
	local bladesMax, billboardsMax = 0, 0
	local prev = {}
	local t0 = os.clock()
	while os.clock() - t0 < duration do
		local char = lp.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			local moving = 0
			local now = {}
			for _, d in ipairs(workspace:GetDescendants()) do
				if d:IsA("BasePart") and not d:IsDescendantOf(char) and d.Transparency < 0.95 then
					local dist = (d.Position - root.Position).Magnitude
					local isNpc = d.Parent and d.Parent:FindFirstChildOfClass("Humanoid")
					if dist < 16 and dist > 1.5 and not isNpc and d.Size.Magnitude < 12 then
						now[d] = d.Position
						if prev[d] and (prev[d] - d.Position).Magnitude > 0.2 then
							moving += 1
						end
					end
				end
			end
			prev = now
			bladesMax = math.max(bladesMax, moving)
		end
		local bb = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BillboardGui") and d.Enabled then bb += 1 end
		end
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if pg then
			for _, d in ipairs(pg:GetDescendants()) do
				if d:IsA("BillboardGui") and d.Enabled then bb += 1 end
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and visible(d) then
					local t = string.sub(d.Text, 1, 60)
					if not texts[t] and #order < 250 then
						texts[t] = true
						table.insert(order, t)
					end
				end
			end
		end
		billboardsMax = math.max(billboardsMax, bb)
		task.wait(0.4)
	end
	local all = string.lower(table.concat(order, " | "))
	local namesSeen = 0
	for _, n in ipairs(names or {}) do
		if string.find(all, string.lower(n), 1, true) then namesSeen += 1 end
	end
	return HttpService:JSONEncode({
		blades_max = bladesMax, billboards_max = billboardsMax,
		wave_word = string.find(all, "wave", 1, true) ~= nil,
		wave2_seen = string.match(all, "wave%D?%D?%D?2[^%d]") ~= nil or string.match(all, "wave%D?%D?%D?2$") ~= nil,
		wave1_seen = string.match(all, "wave%D?%D?%D?1[^%d]") ~= nil or string.match(all, "wave%D?%D?%D?1$") ~= nil,
		timer_seen = string.match(all, "%d+:%d%d") ~= nil or string.match(all, "%d+s[^%a]") ~= nil,
		health_seen = string.find(all, "/ 100", 1, true) ~= nil or string.find(all, "/100", 1, true) ~= nil
			or string.find(all, "hp", 1, true) ~= nil or string.find(all, "health", 1, true) ~= nil,
		gameover_seen = string.find(all, "game over", 1, true) ~= nil or string.find(all, "gameover", 1, true) ~= nil,
		shop_names_seen = namesSeen,
		errors = Probe.errors(),
		sample = table.move(order, 1, math.min(#order, 12), 1, {}),
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

return Probe
