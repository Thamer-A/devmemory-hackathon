-- Always-on HUD: wave, countdown, zombies left (top centre), coins and health (bottom left).
-- Wave data comes from workspace attributes published by Zombies.server.lua.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(game.ReplicatedStorage.Shared.Config).Ui
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Top bar: three equal stat cells.
local top = UiKit.panel(gui)
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 12)
top.Size = UDim2.fromOffset(420, 64)

local function statCell(index: number, caption: string, color: Color3)
	local cell = Instance.new("Frame")
	cell.BackgroundTransparency = 1
	cell.Position = UDim2.new((index - 1) / 3, 0, 0, 0)
	cell.Size = UDim2.new(1 / 3, 0, 1, 0)
	cell.Parent = top

	local cap = UiKit.label(cell, caption, 12, Theme.TextDim, true)
	cap.Position = UDim2.fromOffset(0, 8)
	cap.Size = UDim2.new(1, 0, 0, 14)

	local value = UiKit.label(cell, "-", 26, color, true)
	value.Position = UDim2.fromOffset(0, 24)
	value.Size = UDim2.new(1, 0, 0, 32)
	return value
end

local waveValue = statCell(1, "WAVE", Theme.Accent)
local timerValue = statCell(2, "NEXT WAVE", Theme.Text)
local zombiesValue = statCell(3, "ZOMBIES LEFT", Theme.Danger)

for i = 1, 2 do
	local divider = Instance.new("Frame")
	divider.AnchorPoint = Vector2.new(0.5, 0.5)
	divider.Position = UDim2.new(i / 3, 0, 0.5, 0)
	divider.Size = UDim2.new(0, 1, 0.55, 0)
	divider.BackgroundColor3 = Theme.Accent
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = top
end

-- Bottom left: coins + health bar.
local status = UiKit.panel(gui)
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.new(0, 16, 1, -16)
status.Size = UDim2.fromOffset(260, 78)

local coinsLabel = UiKit.label(status, "0", 24, Theme.Coin, true)
coinsLabel.Position = UDim2.fromOffset(14, 8)
coinsLabel.Size = UDim2.new(1, -28, 0, 28)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left

local coinsCaption = UiKit.label(status, "COINS", 12, Theme.TextDim, true)
coinsCaption.Position = UDim2.fromOffset(14, 8)
coinsCaption.Size = UDim2.new(1, -28, 0, 28)
coinsCaption.TextXAlignment = Enum.TextXAlignment.Right

local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(14, 44)
barBack.Size = UDim2.new(1, -28, 0, 22)
barBack.BackgroundColor3 = Theme.PanelLight
barBack.BorderSizePixel = 0
barBack.Parent = status
UiKit.corner(barBack, 8)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = Theme.Health
barFill.BorderSizePixel = 0
barFill.Parent = barBack
UiKit.corner(barFill, 8)

local healthText = UiKit.label(barBack, "", 13, Theme.Text, true)
healthText.Size = UDim2.fromScale(1, 1)
healthText.ZIndex = 2

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refreshWave()
	waveValue.Text = tostring(workspace:GetAttribute("Wave") or "-")
	zombiesValue.Text = tostring(workspace:GetAttribute("ZombiesLeft") or "-")
end

local function refreshTimer()
	local endsAt = workspace:GetAttribute("BreakEndsAt") or 0
	local remaining = endsAt - workspace:GetServerTimeNow()
	if endsAt > 0 and remaining > 0 then
		timerValue.Text = formatTime(remaining)
		timerValue.TextColor3 = if remaining <= 5 then Theme.Danger else Theme.Accent
	else
		timerValue.Text = "FIGHT!"
		timerValue.TextColor3 = Theme.Text
	end
end

local function refreshHealth()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local health = humanoid and math.max(humanoid.Health, 0) or 0
	local maxHealth = humanoid and humanoid.MaxHealth or 1
	local fraction = math.clamp(health / maxHealth, 0, 1)
	barFill.Size = UDim2.fromScale(fraction, 1)
	barFill.BackgroundColor3 = if fraction <= 0.25 then Theme.Danger else Theme.Health
	healthText.Text = string.format("%d / %d", math.ceil(health), maxHealth)
end

local function refreshCoins()
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Coins")
	coinsLabel.Text = tostring(value and value.Value or 0)
end

workspace:GetAttributeChangedSignal("Wave"):Connect(refreshWave)
workspace:GetAttributeChangedSignal("ZombiesLeft"):Connect(refreshWave)

-- Timer and health change continuously (Humanoid max/current are polled so respawns just work).
-- Connected before waiting on leaderstats so a slow leaderstats can't leave the HUD blank.
RunService.RenderStepped:Connect(function()
	refreshTimer()
	refreshHealth()
end)

refreshWave()
refreshCoins()
player:WaitForChild("leaderstats"):WaitForChild("Coins"):GetPropertyChangedSignal("Value"):Connect(refreshCoins)
refreshCoins()
