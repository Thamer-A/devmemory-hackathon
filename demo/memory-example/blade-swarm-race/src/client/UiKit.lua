-- Small builders shared by the HUD and shop so every panel has the same look.
local Theme = require(game.ReplicatedStorage.Shared.Config).Ui

local UiKit = {}

function UiKit.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.Corner)
	c.Parent = parent
end

function UiKit.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UiKit.panel(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.Panel
	f.BackgroundTransparency = 0.08
	f.BorderSizePixel = 0
	f.Parent = parent
	UiKit.corner(f)
	UiKit.stroke(f, Theme.Accent, 1.5, 0.55)
	return f
end

function UiKit.label(parent: Instance, text: string, size: number, color: Color3?, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color or Theme.Text
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.Parent = parent
	return l
end

return UiKit
