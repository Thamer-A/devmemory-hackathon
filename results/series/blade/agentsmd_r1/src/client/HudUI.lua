-- Always-on HUD. Pure view: reads workspace attrs Wave / ZombiesLeft / NextWaveAt, leaderstats Coins,
-- and the local Humanoid's health.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UIKit = require(script.Parent.UIKit)

local U = Config.UI
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Top-center: wave, countdown, zombies left
local top = UIKit.panel(gui)
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 12)
top.Size = UDim2.fromOffset(300, 78)

local waveLabel = UIKit.label(top, "WAVE 0", 26, U.Accent)
waveLabel.Position = UDim2.fromOffset(0, 6)
waveLabel.Size = UDim2.new(1, 0, 0, 30)

local function statLabel(x: number): TextLabel
	local l = UIKit.label(top, "", 16, U.Text, Enum.Font.GothamMedium)
	l.Position = UDim2.new(x, 0, 0, 44)
	l.Size = UDim2.new(0.5, 0, 0, 24)
	return l
end
local zombiesLabel = statLabel(0)
local timerLabel = statLabel(0.5)

-- Bottom-left: health bar
local hp = UIKit.panel(gui)
hp.AnchorPoint = Vector2.new(0, 1)
hp.Position = UDim2.new(0, 16, 1, -16)
hp.Size = UDim2.fromOffset(280, 34)

local track = Instance.new("Frame")
track.Position = UDim2.fromOffset(6, 6)
track.Size = UDim2.new(1, -12, 1, -12)
track.BackgroundColor3 = U.PanelLight
track.BorderSizePixel = 0
track.Parent = hp
UIKit.corner(track, 8)

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(1, 1)
fill.BackgroundColor3 = U.HealthGood
fill.BorderSizePixel = 0
fill.Parent = track
UIKit.corner(fill, 8)

local hpText = UIKit.label(track, "", 14, Color3.new(1, 1, 1))
hpText.Size = UDim2.fromScale(1, 1)
hpText.ZIndex = 2

-- Bottom-right: coins
local coinPanel = UIKit.panel(gui)
coinPanel.AnchorPoint = Vector2.new(1, 1)
coinPanel.Position = UDim2.new(1, -16, 1, -16)
coinPanel.Size = UDim2.fromOffset(150, 34)

local coinLabel = UIKit.label(coinPanel, "", 20, U.Coins)
coinLabel.Size = UDim2.fromScale(1, 1)

local function updateWave()
	waveLabel.Text = `WAVE {workspace:GetAttribute("Wave") or 0}`
	zombiesLabel.Text = `Zombies: {workspace:GetAttribute("ZombiesLeft") or 0}`
end
workspace:GetAttributeChangedSignal("Wave"):Connect(updateWave)
workspace:GetAttributeChangedSignal("ZombiesLeft"):Connect(updateWave)
updateWave()

local function bindCoins()
	local stats = player:WaitForChild("leaderstats")
	local coins = stats:WaitForChild("Coins")
	local function update()
		coinLabel.Text = `{coins.Value} coins`
	end
	coins.Changed:Connect(update)
	update()
end
task.spawn(bindCoins)

local function updateHealth()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local health = humanoid and math.max(humanoid.Health, 0) or 0
	local max = humanoid and humanoid.MaxHealth or Config.Player.BaseMaxHealth
	local ratio = math.clamp(health / max, 0, 1)
	fill.Size = UDim2.fromScale(ratio, 1)
	fill.BackgroundColor3 = U.HealthLow:Lerp(U.HealthGood, ratio)
	hpText.Text = `{math.ceil(health)} / {math.ceil(max)}`
end

-- Countdown ticks every frame; health polled too so Vitality / respawn changes need no extra wiring.
RunService.RenderStepped:Connect(function()
	local at = workspace:GetAttribute("NextWaveAt") or 0
	if at > 0 then
		timerLabel.Text = `Next wave: {math.max(0, math.ceil(at - workspace:GetServerTimeNow()))}s`
		timerLabel.TextColor3 = U.Accent
	else
		timerLabel.Text = "Fight!"
		timerLabel.TextColor3 = U.TextDim
	end
	updateHealth()
end)
