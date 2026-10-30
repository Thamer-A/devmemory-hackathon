local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Theme = Config.Theme
local Effects = Config.Effects

-- Invisible anchored part that carries a billboard or emitter, cleaned up by Debris.
local function anchor(position, lifetime)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = workspace
	Debris:AddItem(part, lifetime)
	return part
end

local function popup(position, text, color, textSize)
	local part = anchor(position, Effects.PopupLifetime + 0.1)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = Effects.PopupSize
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard

	local info = TweenInfo.new(Effects.PopupLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, info, { Position = position + Vector3.new(0, Effects.PopupRise, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

Remotes.ZombieHit.OnClientEvent:Connect(function(position, damage)
	local jitter = Vector3.new((math.random() - 0.5) * 2, 3, (math.random() - 0.5) * 2)
	popup(position + jitter, tostring(math.round(damage)), Effects.DamageColor, 22)
end)

Remotes.ZombieKilled.OnClientEvent:Connect(function(position)
	local part = anchor(position, Effects.BurstLifetime + 0.2)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(Effects.BurstColor)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(Effects.BurstLifetime * 0.5, Effects.BurstLifetime)
	emitter.Speed = NumberRange.new(Effects.BurstSpeed * 0.5, Effects.BurstSpeed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = part
	emitter:Emit(Effects.BurstCount)
end)

Remotes.CoinsEarned.OnClientEvent:Connect(function(position, amount)
	popup(position + Vector3.new(0, Effects.CoinPopupHeight, 0), `+{amount}`, Effects.CoinColor, 28)
end)
