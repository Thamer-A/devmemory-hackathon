local Players = game:GetService("Players")

local UIController = {}

local THEME = {
	panel = Color3.fromRGB(28, 30, 40),
	panelStroke = Color3.fromRGB(70, 75, 100),
	button = Color3.fromRGB(70, 130, 220),
	buttonHover = Color3.fromRGB(90, 150, 240),
	text = Color3.fromRGB(235, 238, 245),
	font = Enum.Font.GothamMedium,
}

local screenGui: ScreenGui? = nil
local panels: { [string]: Frame } = {}

function UIController.getTheme()
	return THEME
end

function UIController.getRoot(): ScreenGui
	if screenGui == nil then
		local gui = Instance.new("ScreenGui")
		gui.Name = "CoinRushUI"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		screenGui = gui
	end
	return screenGui :: ScreenGui
end

function UIController.createPanel(name: string, size: UDim2, position: UDim2): Frame
	local existing = panels[name]
	if existing then
		return existing
	end

	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = THEME.panel
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = UIController.getRoot()

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.panelStroke
	stroke.Thickness = 1
	stroke.Parent = panel

	panels[name] = panel
	return panel
end

function UIController.getPanel(name: string): Frame?
	return panels[name]
end

function UIController.createLabel(parent: GuiObject, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 24)
	label.Font = THEME.font
	label.TextSize = 18
	label.TextColor3 = THEME.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function UIController.createButton(parent: GuiObject, text: string, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 100, 0, 32)
	button.BackgroundColor3 = THEME.button
	button.AutoButtonColor = false
	button.Font = THEME.font
	button.TextSize = 16
	button.TextColor3 = THEME.text
	button.Text = text
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	button.MouseEnter:Connect(function()
		if button.Active then
			button.BackgroundColor3 = THEME.buttonHover
		end
	end)
	button.MouseLeave:Connect(function()
		if button.Active then
			button.BackgroundColor3 = THEME.button
		end
	end)
	button.Activated:Connect(function()
		if button.Active then
			onClick()
		end
	end)

	return button
end

function UIController.toggle(panelName: string)
	local panel = panels[panelName]
	if panel == nil then
		return
	end
	local willShow = not panel.Visible
	for name, other in panels do
		if other:GetAttribute("Modal") then
			other.Visible = false
		end
		if name == panelName then
			panel.Visible = willShow
		end
	end
end

function UIController.init()
	UIController.getRoot()
end

return UIController
