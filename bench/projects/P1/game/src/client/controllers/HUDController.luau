local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Assets = require(Shared.Assets)
local MathUtil = require(Shared.MathUtil)
local Remotes = require(Shared.Remotes)

local UIController = require(script.Parent.UIController)

local HUDController = {}

local coinLabel: TextLabel
local roundLabel: TextLabel
local flash: Frame

local FLASH_PEAK = 0.6
local FLASH_FADE = 0.4

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function buildCoinCounter(hud: Frame)
	local row = Instance.new("Frame")
	row.Name = "CoinRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -16, 0, 36)
	row.Position = UDim2.new(0, 8, 0, 8)
	row.Parent = hud

	local icon = Instance.new("ImageLabel")
	icon.Name = "CoinIcon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(32, 32)
	icon.Image = Assets.get("CoinIcon") or ""
	icon.Parent = row

	coinLabel = UIController.createLabel(row, "0")
	coinLabel.Name = "Coins"
	coinLabel.Position = UDim2.fromOffset(40, 4)
	coinLabel.Size = UDim2.new(1, -40, 0, 28)
	coinLabel.TextSize = 24
end

local function buildRoundLabel(hud: Frame)
	roundLabel = UIController.createLabel(hud, "Waiting...")
	roundLabel.Name = "Round"
	roundLabel.Position = UDim2.new(0, 8, 0, 52)
	roundLabel.Size = UDim2.new(1, -16, 0, 24)
end

local function buildFlash()
	flash = Instance.new("Frame")
	flash.Name = "HitFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Active = false
	flash.ZIndex = 10
	flash.Parent = UIController.getRoot()
end

local function playHitFlash()
	flash.BackgroundTransparency = FLASH_PEAK
	TweenService:Create(flash, TweenInfo.new(FLASH_FADE), { BackgroundTransparency = 1 }):Play()
end

function HUDController.init()
	local hud = UIController.createPanel("HUD", UDim2.fromOffset(220, 84), UDim2.new(0, 12, 0, 12))
	hud.Visible = true

	buildCoinCounter(hud)
	buildRoundLabel(hud)
	buildFlash()
end

function HUDController.start()
	Remotes.get("CoinsChanged").OnClientEvent:Connect(function(total: number)
		coinLabel.Text = MathUtil.formatNumber(total)
	end)

	Remotes.get("RoundState").OnClientEvent:Connect(function(info)
		if info.state == "Playing" then
			roundLabel.Text = "Survive! " .. formatTime(info.timeLeft)
		else
			roundLabel.Text = "Next round in " .. formatTime(info.timeLeft)
		end
	end)

	Remotes.get("EnemyHit").OnClientEvent:Connect(function()
		playHitFlash()
	end)
end

return HUDController
