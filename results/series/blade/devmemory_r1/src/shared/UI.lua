-- Small helpers so the HUD and shop share one look (colors live in Config.Theme).
local Config = require(script.Parent.Config)
local Theme = Config.Theme

local UI = {}

function UI.round(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.CornerRadius)
	corner.Parent = instance
	return corner
end

function UI.stroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Accent
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

-- Dark navy rounded frame with a thin cyan outline.
function UI.panel(parent, props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.Panel
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	for key, value in props or {} do
		frame[key] = value
	end
	frame.Parent = parent
	UI.round(frame)
	UI.stroke(frame, Theme.Accent, 1.5, 0.35)
	return frame
end

function UI.label(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.TextColor3 = Theme.Text
	label.TextSize = 18
	for key, value in props or {} do
		label[key] = value
	end
	label.Parent = parent
	return label
end

return UI
