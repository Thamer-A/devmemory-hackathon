local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)

local UI = Config.UI
local W = Config.Waves
local player = Players.LocalPlayer

local coins = player:WaitForChild(Config.Stats.Folder):WaitForChild(Config.Stats.Coins)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "HudGui"
gui.ResetOnSpawn = false

local function makePanel(size: UDim2, position: UDim2, anchor: Vector2): Frame
	local panel = Instance.new("Frame")
	panel.Size = size
	panel.Position = position
	panel.AnchorPoint = anchor
	panel.BackgroundColor3 = UI.Panel
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UI.CornerRadius
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.Accent
	stroke.Transparency = 0.45
	stroke.Thickness = 1.5
	stroke.Parent = panel
	return panel
end

local function makeLabel(text: string, size: UDim2, position: UDim2, font: Enum.Font, textSize: number, color: Color3, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	return label
end

-- Top centre: wave, countdown, zombies left.
local top = makePanel(UDim2.fromOffset(380, 66), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0))

local function makeStat(column: number, caption: string, valueColor: Color3): (TextLabel, TextLabel)
	local x = (column - 1) / 3
	local captionLabel = makeLabel(caption, UDim2.new(1 / 3, 0, 0, 20), UDim2.new(x, 0, 0, 8), Enum.Font.GothamMedium, 12, UI.TextDim, top)
	local value = makeLabel("-", UDim2.new(1 / 3, 0, 0, 30), UDim2.new(x, 0, 0, 28), Enum.Font.GothamBold, 26, valueColor, top)
	return captionLabel, value
end

local _, waveValue = makeStat(1, "WAVE", UI.Accent)
local timerCaption, timerValue = makeStat(2, "NEXT WAVE", UI.Text)
local _, zombiesValue = makeStat(3, "ZOMBIES LEFT", UI.Text)

for column = 1, 2 do
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0, 1, 0.6, 0)
	divider.Position = UDim2.new(column / 3, 0, 0.2, 0)
	divider.BackgroundColor3 = UI.Accent
	divider.BackgroundTransparency = 0.7
	divider.BorderSizePixel = 0
	divider.Parent = top
end

-- Bottom left: health bar and coins.
local bottom = makePanel(UDim2.fromOffset(280, 84), UDim2.new(0, 16, 1, -16), Vector2.new(0, 1))

makeLabel("HEALTH", UDim2.fromOffset(100, 16), UDim2.fromOffset(14, 8), Enum.Font.GothamMedium, 12, UI.TextDim, bottom).TextXAlignment =
	Enum.TextXAlignment.Left
local healthText = makeLabel("", UDim2.fromOffset(120, 16), UDim2.new(1, -134, 0, 8), Enum.Font.GothamBold, 13, UI.Text, bottom)
healthText.TextXAlignment = Enum.TextXAlignment.Right

local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(1, -28, 0, 16)
barBack.Position = UDim2.fromOffset(14, 28)
barBack.BackgroundColor3 = UI.PanelLight
barBack.BorderSizePixel = 0
barBack.Parent = bottom
local barBackCorner = Instance.new("UICorner")
barBackCorner.CornerRadius = UDim.new(0, 8)
barBackCorner.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(1, 1)
barFill.BackgroundColor3 = UI.HealthHigh
barFill.BorderSizePixel = 0
barFill.Parent = barBack
local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0, 8)
barFillCorner.Parent = barFill

local coinLabel = makeLabel("", UDim2.new(1, -28, 0, 24), UDim2.fromOffset(14, 52), Enum.Font.GothamBold, 20, UI.Coin, bottom)
coinLabel.TextXAlignment = Enum.TextXAlignment.Left

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function refresh()
	waveValue.Text = tostring(workspace:GetAttribute(W.WaveAttribute) or 0)
	zombiesValue.Text = tostring(workspace:GetAttribute(W.ZombiesLeftAttribute) or 0)

	local remaining = (workspace:GetAttribute(W.BreakAttribute) or 0) - workspace:GetServerTimeNow()
	if remaining > 0 then
		timerCaption.Text = "NEXT WAVE"
		timerValue.Text = formatTime(remaining)
		timerValue.TextColor3 = remaining <= 5 and UI.HealthLow or UI.Accent
	else
		timerCaption.Text = "STATUS"
		timerValue.Text = "FIGHT!"
		timerValue.TextColor3 = UI.Text
	end

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local health = humanoid and math.max(humanoid.Health, 0) or 0
	local maxHealth = humanoid and math.max(humanoid.MaxHealth, 1) or 1
	local fraction = math.clamp(health / maxHealth, 0, 1)
	barFill.Size = UDim2.fromScale(fraction, 1)
	barFill.BackgroundColor3 = UI.HealthLow:Lerp(UI.HealthHigh, fraction)
	healthText.Text = string.format("%d / %d", math.ceil(health), math.ceil(maxHealth))

	coinLabel.Text = "● " .. coins.Value .. " coins"
end

gui.Parent = player:WaitForChild("PlayerGui")

RunService.RenderStepped:Connect(refresh)
