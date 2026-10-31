-- Floating damage numbers, zombie death burst and the killer's "+coins" popup. Display only (server fires the remotes).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local fx = Config.Effects

local container = Instance.new("Folder")
container.Name = "LocalFx"
container.Parent = workspace

-- Invisible anchored part at `position`, removed after `lifetime`.
local function anchorAt(position: Vector3, lifetime: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	part.Parent = container
	Debris:AddItem(part, lifetime)
	return part
end

-- Text that rises from `position` and fades out.
local function floatText(position: Vector3, text: string, color: Color3, textSize: number, rise: number, seconds: number)
	local part = anchorAt(position, seconds + 0.1)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = position + Vector3.new(0, rise, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

Remotes.get("DamageNumber").OnClientEvent:Connect(function(position: Vector3, damage: number)
	local c = fx.DamageNumber
	local jitter = Vector3.new((math.random() * 2 - 1) * c.Jitter, 2, (math.random() * 2 - 1) * c.Jitter)
	floatText(position + jitter, tostring(math.round(damage)), c.Color, c.TextSize, c.RiseStuds, c.Seconds)
end)

Remotes.get("ZombieDeathFx").OnClientEvent:Connect(function(position: Vector3)
	local c = fx.DeathBurst
	local part = anchorAt(position, c.Lifetime + 0.5)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(c.Color)
	emitter.Lifetime = NumberRange.new(c.Lifetime * 0.5, c.Lifetime)
	emitter.Speed = NumberRange.new(c.Speed * 0.5, c.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(c.Size, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.LightEmission = 0.5
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = part
	emitter:Emit(c.Count)
end)

Remotes.get("CoinPopup").OnClientEvent:Connect(function(position: Vector3, coins: number)
	local c = fx.CoinPopup
	floatText(position + Vector3.new(0, c.HeightAbove, 0), "+" .. coins, Config.UI.Gold, c.TextSize, c.RiseStuds, c.Seconds)
end)
