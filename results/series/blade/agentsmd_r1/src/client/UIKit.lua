-- Small helpers so HUD and shop share the same navy/cyan look.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local U = Config.UI

local UIKit = {}

function UIKit.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or U.Corner)
	c.Parent = parent
end

function UIKit.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- Dark navy rounded panel with a thin cyan outline.
function UIKit.panel(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = U.Panel
	f.BackgroundTransparency = 0.05
	f.BorderSizePixel = 0
	f.Parent = parent
	UIKit.corner(f)
	UIKit.stroke(f, U.Accent, 1.5, 0.55)
	return f
end

function UIKit.label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color or U.Text
	l.Font = font or Enum.Font.GothamBold
	l.Parent = parent
	return l
end

return UIKit
