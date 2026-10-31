-- Shared look for the HUD and the shop.
local Theme = {}

Theme.Panel = Color3.fromRGB(14, 20, 38) -- dark navy
Theme.PanelLight = Color3.fromRGB(24, 33, 58)
Theme.Accent = Color3.fromRGB(0, 229, 255) -- cyan
Theme.Gold = Color3.fromRGB(255, 200, 40)
Theme.Text = Color3.fromRGB(235, 241, 250)
Theme.TextDim = Color3.fromRGB(140, 153, 180)
Theme.Danger = Color3.fromRGB(255, 82, 82)
Theme.Health = Color3.fromRGB(70, 220, 120)

Theme.Rarity = {
	Common = Color3.fromRGB(160, 165, 175),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(176, 92, 255),
}

Theme.PanelTransparency = 0.08
Theme.Corner = UDim.new(0, 12)
Theme.FontBold = Enum.Font.GothamBold
Theme.Font = Enum.Font.Gotham

function Theme.round(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Corner
	corner.Parent = instance
	return corner
end

function Theme.stroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Accent
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or 0.4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function Theme.panel(parent)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.Panel
	frame.BackgroundTransparency = Theme.PanelTransparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.round(frame)
	Theme.stroke(frame, Theme.Accent, 1.5, 0.6)
	return frame
end

function Theme.label(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.TextColor3 = Theme.Text
	label.TextSize = 18
	for key, value in props do
		label[key] = value
	end
	label.Parent = parent
	return label
end

return Theme
