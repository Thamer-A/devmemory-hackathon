local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FX = Config.Effects

-- Invisible anchored part that carries an effect at a world position.
local function makeAnchor(position: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.Position = position
	part.Parent = workspace
	return part
end

-- Floating text that rises and fades out.
local function popup(position: Vector3, text: string, color: Color3, textSize: number, lifetime: number, rise: number)
	local anchor = makeAnchor(position)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = billboard

	local info = TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = position + Vector3.new(0, rise, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, lifetime + 0.1)
end

Remotes.ZombieHit.OnClientEvent:Connect(function(position: Vector3, damage: number)
	local spread = FX.DamageSpread
	local jitter = Vector3.new((math.random() * 2 - 1) * spread, 0, (math.random() * 2 - 1) * spread)
	popup(position + Vector3.new(0, 3, 0) + jitter, tostring(math.floor(damage + 0.5)), FX.DamageColor, 22, FX.DamageLifetime, FX.DamageRise)
end)

Remotes.ZombieDied.OnClientEvent:Connect(function(position: Vector3)
	local anchor = makeAnchor(position)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(FX.BurstColor)
	emitter.LightEmission = 0.4
	emitter.Lifetime = NumberRange.new(FX.BurstLifetime * 0.6, FX.BurstLifetime)
	emitter.Speed = NumberRange.new(FX.BurstSpeed * 0.5, FX.BurstSpeed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = anchor
	emitter:Emit(FX.BurstCount)
	Debris:AddItem(anchor, FX.BurstLifetime + 0.5)
end)

-- Only the killer receives this.
Remotes.CoinReward.OnClientEvent:Connect(function(position: Vector3, amount: number)
	popup(position + Vector3.new(0, 5, 0), "+" .. amount .. " coins", Config.UI.Coin, 26, FX.CoinLifetime, FX.CoinRise)
end)
