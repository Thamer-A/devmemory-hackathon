local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(Shared:WaitForChild("Theme"))
local A = Config.Attributes

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Top bar: wave, timer, zombies left -----------------------------------------------

local top = Theme.panel(gui)
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 12)
top.Size = UDim2.fromOffset(420, 64)

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Parent = top

-- A stat block is a small caption over a big value; returns the value label.
local function statBlock(caption, valueColor)
	local block = Instance.new("Frame")
	block.BackgroundTransparency = 1
	block.Size = UDim2.new(1 / 3, 0, 1, 0)
	block.Parent = top

	local captionLabel = Theme.label(block, {
		Text = caption,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.TextDim,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 14),
	})
	return captionLabel, Theme.label(block, {
		Text = "-",
		TextSize = 26,
		TextColor3 = valueColor,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 32),
	})
end

local _, waveLabel = statBlock("WAVE", Theme.Accent)
local timerCaption, timerLabel = statBlock("WAVE TIME", Theme.Text)
local _, zombiesLabel = statBlock("ZOMBIES LEFT", Theme.Danger)

-- Bottom left: health bar and coins ------------------------------------------------

local bottom = Theme.panel(gui)
bottom.AnchorPoint = Vector2.new(0, 1)
bottom.Position = UDim2.new(0, 16, 1, -16)
bottom.Size = UDim2.fromOffset(300, 84)

local coinsLabel = Theme.label(bottom, {
	Text = "0",
	TextSize = 24,
	TextColor3 = Theme.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 0, 28),
})

local healthTrack = Instance.new("Frame")
healthTrack.BackgroundColor3 = Theme.PanelLight
healthTrack.BorderSizePixel = 0
healthTrack.Position = UDim2.fromOffset(16, 46)
healthTrack.Size = UDim2.new(1, -32, 0, 24)
healthTrack.Parent = bottom
Theme.round(healthTrack, UDim.new(0, 8))

local healthFill = Instance.new("Frame")
healthFill.BackgroundColor3 = Theme.Health
healthFill.BorderSizePixel = 0
healthFill.Size = UDim2.fromScale(1, 1)
healthFill.Parent = healthTrack
Theme.round(healthFill, UDim.new(0, 8))

local healthLabel = Theme.label(healthTrack, {
	Text = "",
	TextSize = 14,
	ZIndex = 2,
	Size = UDim2.fromScale(1, 1),
})

-- Updating -------------------------------------------------------------------------

local function getCoins()
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	return coins and coins.Value or 0
end

local function updateHealth()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local health = humanoid and math.max(0, humanoid.Health) or 0
	local maxHealth = humanoid and math.max(1, humanoid.MaxHealth) or 1
	local fraction = math.clamp(health / maxHealth, 0, 1)

	healthFill.Size = UDim2.fromScale(fraction, 1)
	healthFill.BackgroundColor3 = if fraction > 0.5
		then Theme.Health
		elseif fraction > 0.25 then Theme.Gold
		else Theme.Danger
	healthLabel.Text = `{math.ceil(health)} / {math.ceil(maxHealth)}`
end

RunService.Heartbeat:Connect(function()
	waveLabel.Text = tostring(workspace:GetAttribute(A.Wave) or 0)
	zombiesLabel.Text = tostring(workspace:GetAttribute(A.ZombiesLeft) or 0)
	coinsLabel.Text = `● {getCoins()}`

	if workspace:GetAttribute(A.Intermission) then
		local endsAt = workspace:GetAttribute(A.BreakEndsAt) or 0
		local remaining = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
		timerCaption.Text = "NEXT WAVE"
		timerLabel.Text = string.format("%d:%02d", remaining // 60, remaining % 60)
		timerLabel.TextColor3 = Theme.Accent
	else
		local startedAt = workspace:GetAttribute(A.WaveStartedAt)
		local elapsed = startedAt and math.max(0, math.floor(workspace:GetServerTimeNow() - startedAt)) or 0
		timerCaption.Text = "WAVE TIME"
		timerLabel.Text = string.format("%d:%02d", elapsed // 60, elapsed % 60)
		timerLabel.TextColor3 = Theme.Danger
	end

	updateHealth()
end)
