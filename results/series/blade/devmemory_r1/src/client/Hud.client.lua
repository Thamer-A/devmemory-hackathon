local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UI = require(Shared.UI)
local Theme = Config.Theme

local player = Players.LocalPlayer
local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Top bar: wave | timer | zombies left
local top = UI.panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(420, 64),
})

local function stat(index, caption, color)
	local cell = Instance.new("Frame")
	cell.BackgroundTransparency = 1
	cell.Position = UDim2.fromScale((index - 1) / 3, 0)
	cell.Size = UDim2.fromScale(1 / 3, 1)
	cell.Parent = top
	UI.label(cell, {
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 8),
		Text = caption,
		TextSize = 12,
		Font = Theme.FontBody,
		TextColor3 = Theme.TextDim,
	})
	return UI.label(cell, {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 24),
		TextSize = 26,
		TextColor3 = color,
	})
end

local waveValue = stat(1, "WAVE", Theme.Accent)
local timerValue = stat(2, "NEXT WAVE", Theme.Text)
local zombieValue = stat(3, "ZOMBIES LEFT", Theme.Text)

for i = 1, 2 do
	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = Theme.Accent
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.AnchorPoint = Vector2.new(0.5, 0.5)
	divider.Position = UDim2.fromScale(i / 3, 0.5)
	divider.Size = UDim2.new(0, 1, 0.6, 0)
	divider.Parent = top
end

-- Bottom left: coins + health bar
local bottom = UI.panel(gui, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(280, 74),
})

local coinLabel = UI.label(bottom, {
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.new(1, -28, 0, 28),
	TextSize = 22,
	TextColor3 = Theme.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
})

local barBack = Instance.new("Frame")
barBack.BackgroundColor3 = Theme.PanelLight
barBack.BorderSizePixel = 0
barBack.Position = UDim2.fromOffset(14, 40)
barBack.Size = UDim2.new(1, -28, 0, 22)
barBack.Parent = bottom
UI.round(barBack, 8)

local barFill = Instance.new("Frame")
barFill.BackgroundColor3 = Theme.Health
barFill.BorderSizePixel = 0
barFill.Size = UDim2.fromScale(1, 1)
barFill.Parent = barBack
UI.round(barFill, 8)

local healthLabel = UI.label(barBack, {
	Size = UDim2.fromScale(1, 1),
	TextSize = 14,
	ZIndex = 2,
})

local function updateCoins()
	coinLabel.Text = `● {coins.Value} coins`
end
coins:GetPropertyChangedSignal("Value"):Connect(updateCoins)
updateCoins()

local function updateHealth()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local health = humanoid and math.max(0, humanoid.Health) or 0
	local max = humanoid and humanoid.MaxHealth or Config.Shop.BaseMaxHealth
	local ratio = math.clamp(health / max, 0, 1)
	barFill.Size = UDim2.fromScale(ratio, 1)
	barFill.BackgroundColor3 = Theme.HealthLow:Lerp(Theme.Health, ratio)
	healthLabel.Text = `{math.ceil(health)} / {math.ceil(max)}`
end

local function updateTop()
	waveValue.Text = tostring(workspace:GetAttribute("Wave") or 0)
	zombieValue.Text = tostring(workspace:GetAttribute("ZombiesLeft") or 0)

	if workspace:GetAttribute("ShopOpen") == true then
		local left = math.max(0, (workspace:GetAttribute("BreakEndsAt") or 0) - workspace:GetServerTimeNow())
		timerValue.Text = `{math.ceil(left)}s`
		timerValue.TextColor3 = Theme.Accent
	else
		timerValue.Text = "FIGHT!"
		timerValue.TextColor3 = Theme.HealthLow
	end
end

RunService.RenderStepped:Connect(function()
	updateHealth()
	updateTop()
end)
