-- Small helpers so the HUD and shop share one look (colors/sizes come from Config.UI).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ui = Config.UI

local UIKit = {}

function UIKit.corner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or ui.CornerRadius)
	corner.Parent = parent
	return corner
end

function UIKit.stroke(parent: GuiObject, color: Color3, thickness: number?, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

-- Dark navy rounded panel with a cyan outline.
function UIKit.panel(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = ui.Navy
	frame.BackgroundTransparency = ui.PanelTransparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIKit.corner(frame)
	UIKit.stroke(frame, ui.Accent, 2, 0.4)
	return frame
end

function UIKit.label(parent: Instance, name: string, text: string, size: number, color: Color3?, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color or ui.Text
	label.Font = bold == false and Enum.Font.Gotham or Enum.Font.GothamBold
	label.Parent = parent
	return label
end

return UIKit
