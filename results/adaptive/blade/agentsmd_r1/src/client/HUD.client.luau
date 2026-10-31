-- Always-on HUD: wave info (top center), coins (top right), health bar (bottom left). Display only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UIKit = require(Shared:WaitForChild("UIKit"))

local ui = Config.UI
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Wave panel -----------------------------------------------------------------------------------------------
local wavePanel = UIKit.panel(gui, "WavePanel")
wavePanel.AnchorPoint = Vector2.new(0.5, 0)
wavePanel.Position = UDim2.new(0.5, 0, 0, 14)
wavePanel.Size = UDim2.fromOffset(300, 84)

local waveLabel = UIKit.label(wavePanel, "Wave", "WAVE 1", 26, ui.Accent)
waveLabel.Position = UDim2.fromOffset(0, 6)
waveLabel.Size = UDim2.new(1, 0, 0, 32)

local function statColumn(name: string, x: number, caption: string): TextLabel
	local value = UIKit.label(wavePanel, name, "-", 22)
	value.Position = UDim2.new(x, 0, 0, 38)
	value.Size = UDim2.new(0.5, 0, 0, 24)
	local cap = UIKit.label(wavePanel, name .. "Caption", caption, 12, ui.TextDim, false)
	cap.Position = UDim2.new(x, 0, 0, 62)
	cap.Size = UDim2.new(0.5, 0, 0, 16)
	return value
end

local timerLabel = statColumn("Timer", 0, "NEXT WAVE")
local zombiesLabel = statColumn("ZombiesLeft", 0.5, "ZOMBIES LEFT")

-- Coins panel ----------------------------------------------------------------------------------------------
local coinPanel = UIKit.panel(gui, "CoinPanel")
coinPanel.AnchorPoint = Vector2.new(1, 0)
coinPanel.Position = UDim2.new(1, -14, 0, 14)
coinPanel.Size = UDim2.fromOffset(150, 48)

local coinIcon = Instance.new("Frame")
coinIcon.Name = "Icon"
coinIcon.AnchorPoint = Vector2.new(0, 0.5)
coinIcon.Position = UDim2.new(0, 12, 0.5, 0)
coinIcon.Size = UDim2.fromOffset(24, 24)
coinIcon.BackgroundColor3 = ui.Gold
coinIcon.BorderSizePixel = 0
coinIcon.Parent = coinPanel
UIKit.corner(coinIcon, 12)
UIKit.stroke(coinIcon, Color3.fromRGB(190, 140, 20), 3)

local coinLabel = UIKit.label(coinPanel, "Coins", "0", 24, ui.Gold)
coinLabel.Position = UDim2.fromOffset(44, 0)
coinLabel.Size = UDim2.new(1, -54, 1, 0)
coinLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Health bar -----------------------------------------------------------------------------------------------
local healthPanel = UIKit.panel(gui, "HealthPanel")
healthPanel.AnchorPoint = Vector2.new(0, 1)
healthPanel.Position = UDim2.new(0, 14, 1, -14)
healthPanel.Size = UDim2.fromOffset(280, 42)

local track = Instance.new("Frame")
track.Name = "Track"
track.Position = UDim2.fromOffset(8, 8)
track.Size = UDim2.new(1, -16, 1, -16)
track.BackgroundColor3 = ui.NavyLight
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.Parent = healthPanel
UIKit.corner(track, 8)

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = ui.HealthGood
fill.BorderSizePixel = 0
fill.Parent = track
UIKit.corner(fill, 8)

local healthText = UIKit.label(track, "Text", "100 / 100", 16)
healthText.Size = UDim2.fromScale(1, 1)
healthText.ZIndex = 2

-- Updates --------------------------------------------------------------------------------------------------
local function refreshWave()
	local breakLeft = workspace:GetAttribute("BreakSecondsLeft") or 0
	waveLabel.Text = `WAVE {workspace:GetAttribute("Wave") or 1}`
	zombiesLabel.Text = tostring(workspace:GetAttribute("ZombiesLeft") or 0)
	if breakLeft > 0 then
		timerLabel.Text = string.format("0:%02d", breakLeft)
		timerLabel.TextColor3 = ui.Accent
	else
		timerLabel.Text = "FIGHT!"
		timerLabel.TextColor3 = ui.HealthLow
	end
end

local healthConnections: { RBXScriptConnection } = {}

local function refreshHealth(humanoid: Humanoid?)
	local health = humanoid and math.max(humanoid.Health, 0) or 0
	local maxHealth = humanoid and math.max(humanoid.MaxHealth, 1) or Config.Player.BaseMaxHealth
	local fraction = math.clamp(health / maxHealth, 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = if fraction <= ui.LowHealthFraction then ui.HealthLow else ui.HealthGood
	healthText.Text = `{math.ceil(health)} / {math.ceil(maxHealth)}`
end

local function watchCharacter(character: Model)
	for _, connection in healthConnections do
		connection:Disconnect()
	end
	table.clear(healthConnections)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	table.insert(healthConnections, humanoid.HealthChanged:Connect(function()
		refreshHealth(humanoid)
	end))
	table.insert(healthConnections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		refreshHealth(humanoid)
	end))
	refreshHealth(humanoid)
end

workspace:GetAttributeChangedSignal("Wave"):Connect(refreshWave)
workspace:GetAttributeChangedSignal("BreakSecondsLeft"):Connect(refreshWave)
workspace:GetAttributeChangedSignal("ZombiesLeft"):Connect(refreshWave)
refreshWave()
refreshHealth(nil)

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end

task.spawn(function()
	local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins") :: IntValue
	local function update()
		coinLabel.Text = tostring(coins.Value)
	end
	coins:GetPropertyChangedSignal("Value"):Connect(update)
	update()
end)
