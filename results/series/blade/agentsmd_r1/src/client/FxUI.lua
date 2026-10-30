-- Cosmetic effects driven by server remotes: damage numbers, death burst, "+coins" popup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local F = Config.Fx

-- Invisible anchored anchor part for billboards / emitters.
local function anchor(position: Vector3, lifetime: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Position = position
	p.Parent = workspace
	Debris:AddItem(p, lifetime)
	return p
end

-- Text that floats upward and fades out.
local function floatText(position: Vector3, text: string, color: Color3, size: number, lifetime: number, rise: number)
	local part = anchor(position, lifetime + 0.1)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.Adornee = part
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui

	local info = TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(part, info, { Position = position + Vector3.new(0, rise, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

local function emitter(part: Part, color: Color3, speed: NumberRange, size: number, count: number)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(size, 0)
	e.Lifetime = NumberRange.new(F.BurstLifetime * 0.6, F.BurstLifetime)
	e.Speed = speed
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Rate = 0
	e.Enabled = false
	e.Parent = part
	e:Emit(count)
end

local function burst(position: Vector3)
	local part = anchor(position, F.BurstLifetime + 0.2)
	emitter(part, F.BurstColor, NumberRange.new(14, 28), 0.9, F.BurstCount)
	emitter(part, F.BurstSparkColor, NumberRange.new(20, 36), 0.4, math.floor(F.BurstCount / 2))
end

Remotes.HitFx.OnClientEvent:Connect(function(position: Vector3, damage: number, killed: boolean)
	local scatter = Vector3.new(
		(math.random() * 2 - 1) * F.NumberScatter,
		0,
		(math.random() * 2 - 1) * F.NumberScatter
	)
	floatText(
		position + Vector3.new(0, 3, 0) + scatter,
		tostring(math.round(damage)),
		killed and F.KillColor or F.DamageColor,
		killed and 26 or 20,
		F.NumberLifetime,
		F.NumberRise
	)
	if killed then
		burst(position)
	end
end)

Remotes.CoinFx.OnClientEvent:Connect(function(position: Vector3, coins: number)
	floatText(
		position + Vector3.new(0, F.CoinHeight, 0),
		"+" .. coins,
		Config.UI.Coins,
		28,
		F.CoinLifetime,
		F.CoinRise
	)
end)

return {}
