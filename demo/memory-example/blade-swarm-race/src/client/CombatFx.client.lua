-- Floating damage numbers, zombie death bursts and the killer's "+coins" popup.
-- The server only sends events (see CombatFx in Remotes.lua); all visuals are built here.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Theme = Config.Ui
local Fx = Config.Effects

-- Invisible anchor part with a billboard label that drifts up and fades out.
local function popup(position: Vector3, text: string, color: Color3, textSize: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(math.random() - 0.5, 3, math.random() - 0.5)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	anchor.Parent = workspace
	local info = TweenInfo.new(Fx.PopupLifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = anchor.Position + Vector3.new(0, Fx.PopupRise, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, Fx.PopupLifetime + 0.1)
end

local function burst(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(Config.Zombies.Color, Config.Blades.Color)
	emitter.LightEmission = 0.6
	emitter.Lifetime = NumberRange.new(Fx.BurstLifetime * 0.6, Fx.BurstLifetime)
	emitter.Speed = NumberRange.new(Fx.BurstSpeed * 0.5, Fx.BurstSpeed)
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

	anchor.Parent = workspace
	emitter:Emit(Fx.BurstParticles)
	Debris:AddItem(anchor, Fx.BurstLifetime + 0.5)
end

Remotes.CombatFx.OnClientEvent:Connect(function(kind: string, position: Vector3, amount: number?)
	if typeof(position) ~= "Vector3" then
		return
	end
	if kind == "Hit" then
		popup(position, tostring(math.round(amount or 0)), Fx.HitColor, 22)
	elseif kind == "Kill" then
		burst(position)
	elseif kind == "Coins" then
		popup(position + Vector3.new(0, 2, 0), "+" .. tostring(amount or 0), Theme.Coin, 28)
	end
end)
