--!nonstrict
-- Combat juice: damage numbers, kill bursts, gold pickups text, hurt vignette and camera shake.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Maid = require(Shared.Maid)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local EffectsController = {}

local localPlayer = Players.LocalPlayer
local colors = Theme.Colors
local rng = Random.new()

local MAX_FX = 60
local DAMAGE_RISE = 5
local DAMAGE_DURATION = 0.7
local COIN_RISE = 7
local COIN_DURATION = 1.1
local BURST_COUNT = 18
local BURST_RELEASE_DELAY = 1.2
local PARKED_POSITION = Vector3.new(0, -500, 0)

type Fx = {
	part: Part,
	billboard: BillboardGui,
	label: TextLabel,
	stroke: UIStroke,
	scale: UIScale,
	emitter: ParticleEmitter,
}

local fxFolder: Folder
local pool: { Fx } = {}
local created = 0

local vignette: Frame
local vignetteEdges: { Frame } = {}
local vignetteToken = 0

local shakeStrength = 0
local shakeHumanoid: Humanoid? = nil
local characterMaid = Maid.new()

-- Pooled effect objects ----------------------------------------------------

local function createFx(): Fx
	local part = Theme.new("Part", {
		Name = "Fx",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = PARKED_POSITION,
	}, fxFolder)

	local attachment = Theme.new("Attachment", {}, part)
	local emitter = Theme.new("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(0.35, 0.7),
		Speed = NumberRange.new(14, 26),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -40, 0),
		Drag = 2,
		LightEmission = 1,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, colors.Good),
			ColorSequenceKeypoint.new(1, colors.Gold),
		}),
	}, attachment)

	local billboard = Theme.new("BillboardGui", {
		Size = UDim2.fromOffset(180, 60),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 250,
		Enabled = false,
	}, part)
	local label = Theme.label(billboard, {
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.Title,
		TextScaled = true,
		Text = "",
	})
	local stroke = Theme.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5, Transparency = 0.2 }, label)
	local scale = Theme.new("UIScale", { Scale = 1 }, label)

	created += 1
	return {
		part = part,
		billboard = billboard,
		label = label,
		stroke = stroke,
		scale = scale,
		emitter = emitter,
	}
end

local function acquire(): Fx?
	local fx = table.remove(pool)
	if fx then
		return fx
	end
	if created < MAX_FX then
		return createFx()
	end
	return nil
end

local function release(fx: Fx)
	fx.billboard.Enabled = false
	fx.part.Position = PARKED_POSITION
	table.insert(pool, fx)
end

local function floatText(position: Vector3, text: string, color: Color3, widthScale: number, rise: number, duration: number)
	local fx = acquire()
	if fx == nil then
		return
	end

	fx.part.Position = position
	fx.billboard.Size = UDim2.fromOffset(180 * widthScale, 60 * widthScale)
	fx.billboard.Enabled = true
	fx.label.Text = text
	fx.label.TextColor3 = color
	fx.label.TextTransparency = 0
	fx.stroke.Transparency = 0.2
	fx.scale.Scale = 0.4

	Theme.tween(fx.scale, 0.15, { Scale = 1.2 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay(0.15, function()
		Theme.tween(fx.scale, 0.1, { Scale = 1 })
	end)
	Theme.tween(fx.part, duration, { Position = position + Vector3.new(0, rise, 0) })
	TweenService:Create(
		fx.label,
		TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, duration * 0.5),
		{ TextTransparency = 1 }
	):Play()
	TweenService:Create(
		fx.stroke,
		TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, duration * 0.5),
		{ Transparency = 1 }
	):Play()

	task.delay(duration + 0.05, release, fx)
end

local function burst(position: Vector3)
	local fx = acquire()
	if fx == nil then
		return
	end
	fx.part.Position = position
	fx.emitter:Emit(BURST_COUNT)
	task.delay(BURST_RELEASE_DELAY, release, fx)
end

-- Remote handlers ----------------------------------------------------------

local function onZombieHit(position: Vector3, damage: number)
	local jitter = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
	floatText(position + jitter, tostring(math.floor(damage + 0.5)), colors.Text, 0.8, DAMAGE_RISE, DAMAGE_DURATION)
end

local function onZombieKilled(position: Vector3, coins: number, killerUserId: number)
	burst(position + Vector3.new(0, 1.5, 0))
	if killerUserId == localPlayer.UserId and coins > 0 then
		floatText(position + Vector3.new(0, 4, 0), "+" .. coins .. " coins", colors.Gold, 1.3, COIN_RISE, COIN_DURATION)
	end
end

-- Hurt feedback --------------------------------------------------------------

local function buildVignette()
	local gui = Theme.new("ScreenGui", {
		Name = "BladeSwarmFx",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, localPlayer:WaitForChild("PlayerGui"))

	vignette = Theme.new("Frame", {
		Name = "HurtVignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)

	-- Each edge fades from opaque red at the screen border to clear toward the center.
	local edges = {
		{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.25), rotation = 90 },
		{ position = UDim2.fromScale(0, 0.75), size = UDim2.fromScale(1, 0.25), rotation = 270 },
		{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.18, 1), rotation = 0 },
		{ position = UDim2.fromScale(0.82, 0), size = UDim2.fromScale(0.18, 1), rotation = 180 },
	}
	for _, edge in edges do
		local frame = Theme.new("Frame", {
			Position = edge.position,
			Size = edge.size,
			BackgroundColor3 = colors.Danger,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, vignette)
		Theme.new("UIGradient", {
			Rotation = edge.rotation,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, frame)
		table.insert(vignetteEdges, frame)
	end
end

local function flashVignette(startTransparency: number)
	vignetteToken += 1
	local token = vignetteToken
	vignette.Visible = true
	for _, edge in vignetteEdges do
		edge.BackgroundTransparency = startTransparency
		Theme.tween(edge, 0.5, { BackgroundTransparency = 1 })
	end
	task.delay(0.55, function()
		if token == vignetteToken then
			vignette.Visible = false
		end
	end)
end

local function onHurt(damage: number)
	flashVignette(math.clamp(0.75 - damage * 0.012, 0.3, 0.75))
	shakeStrength = math.max(shakeStrength, math.clamp(damage * 0.015, 0.04, 0.45))
end

local function bindCharacter(character: Model)
	characterMaid:Clean()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil then
		return
	end
	shakeHumanoid = humanoid
	local last = humanoid.Health
	characterMaid:Give(humanoid.HealthChanged:Connect(function(health: number)
		if health < last then
			onHurt(last - health)
		end
		last = health
	end))
	characterMaid:Give(function()
		if shakeHumanoid == humanoid then
			shakeHumanoid = nil
		end
		if humanoid.Parent then
			humanoid.CameraOffset = Vector3.zero
		end
	end)
end

local function onRenderStepped()
	local humanoid = shakeHumanoid
	if humanoid == nil then
		shakeStrength = 0
		return
	end
	if shakeStrength > 0.01 then
		humanoid.CameraOffset = Vector3.new(
			rng:NextNumber(-1, 1) * shakeStrength,
			rng:NextNumber(-1, 1) * shakeStrength,
			0
		)
		shakeStrength *= 0.85
	elseif humanoid.CameraOffset ~= Vector3.zero then
		humanoid.CameraOffset = Vector3.zero
		shakeStrength = 0
	end
end

function EffectsController.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "BladeSwarmFx"
	fxFolder.Parent = workspace
	buildVignette()
end

function EffectsController.start()
	Remotes.get("ZombieHit").OnClientEvent:Connect(onZombieHit)
	Remotes.get("ZombieKilled").OnClientEvent:Connect(onZombieKilled)

	localPlayer.CharacterAdded:Connect(bindCharacter)
	if localPlayer.Character then
		task.spawn(bindCharacter, localPlayer.Character)
	end
	RunService.RenderStepped:Connect(onRenderStepped)
end

return EffectsController
