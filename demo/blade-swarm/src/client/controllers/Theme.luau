--!nonstrict
-- Shared look and feel plus small UI construction helpers. Not a controller (no init/start).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = {}

Theme.Colors = Config.Colors
Theme.PanelTransparency = 0.15

Theme.Fonts = {
	Title = Font.fromEnum(Enum.Font.FredokaOne),
	Body = Font.fromEnum(Enum.Font.GothamMedium),
	Bold = Font.fromEnum(Enum.Font.GothamBold),
}

function Theme.rarityColor(rarity: string): Color3
	local colors: { [string]: Color3 } = Theme.Colors
	return colors[rarity] or Theme.Colors.Common
end

-- Instance factory: Theme.new("Frame", { Name = "X", Parent = gui }). Parent is applied last.
function Theme.new(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance: any = Instance.new(className)
	local resolvedParent = parent
	if props then
		for key, value in props do
			if key == "Parent" then
				resolvedParent = value
			else
				instance[key] = value
			end
		end
	end
	if resolvedParent then
		instance.Parent = resolvedParent
	end
	return instance
end

-- Idempotent: reuses an existing UICorner so panels can be re-rounded.
function Theme.corner(parent: Instance, radius: number?): UICorner
	local existing = parent:FindFirstChildOfClass("UICorner")
	if existing then
		existing.CornerRadius = UDim.new(0, radius or 12)
		return existing
	end
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

-- Idempotent: reuses an existing UIStroke.
function Theme.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local existing = parent:FindFirstChildOfClass("UIStroke")
	if existing then
		existing.Color = color or Color3.new(1, 1, 1)
		existing.Thickness = thickness or 1.5
		existing.Transparency = transparency or 0.8
		return existing
	end
	return Theme.new("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.8,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Theme.padding(parent: Instance, pixels: number): UIPadding
	local pad = UDim.new(0, pixels)
	return Theme.new("UIPadding", {
		PaddingTop = pad,
		PaddingBottom = pad,
		PaddingLeft = pad,
		PaddingRight = pad,
	}, parent)
end

function Theme.gradient(parent: Instance, from: Color3, to: Color3, rotation: number?): UIGradient
	return Theme.new("UIGradient", {
		Color = ColorSequence.new(from, to),
		Rotation = rotation or 90,
	}, parent)
end

-- Dark rounded panel with a subtle stroke.
function Theme.panel(parent: Instance, props: { [string]: any }?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.PanelTransparency,
		BorderSizePixel = 0,
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	local frame = Theme.new("Frame", merged, parent)
	Theme.corner(frame, 12)
	Theme.stroke(frame, Color3.new(1, 1, 1), 1.5, 0.85)
	return frame
end

-- Transparent text label with sensible defaults. props override anything.
function Theme.label(parent: Instance, props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Text,
		TextSize = 18,
		BorderSizePixel = 0,
	}
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return Theme.new("TextLabel", merged, parent)
end

function Theme.textSizeLimit(parent: Instance, minSize: number, maxSize: number): UITextSizeConstraint
	return Theme.new("UITextSizeConstraint", { MinTextSize = minSize, MaxTextSize = maxSize }, parent)
end

function Theme.tween(instance: Instance, duration: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Returns (creating if needed) a UIScale child with the given name.
function Theme.scaleOf(guiObject: GuiObject, name: string?): UIScale
	local key = name or "PopScale"
	local existing = guiObject:FindFirstChild(key)
	if existing and existing:IsA("UIScale") then
		return existing
	end
	return Theme.new("UIScale", { Name = key, Scale = 1 }, guiObject)
end

-- Springy scale-in from 0 (optionally delayed).
function Theme.popIn(guiObject: GuiObject, delaySeconds: number?, duration: number?)
	local scale = Theme.scaleOf(guiObject)
	scale.Scale = 0
	task.delay(delaySeconds or 0, function()
		if scale.Parent then
			Theme.tween(scale, duration or 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end)
end

-- Quick punch (scale up then settle) used for emphasis.
function Theme.punch(guiObject: GuiObject, amount: number?)
	local scale = Theme.scaleOf(guiObject, "PunchScale")
	scale.Scale = amount or 1.15
	Theme.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

return Theme
