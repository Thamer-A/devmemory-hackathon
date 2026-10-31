local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("Theme"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "GameOver"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Theme.panel(gui)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.4)
panel.Size = UDim2.fromOffset(420, 150)

Theme.label(panel, {
	Text = "GAME OVER",
	TextSize = 40,
	TextColor3 = Theme.Danger,
	Position = UDim2.fromOffset(0, 16),
	Size = UDim2.new(1, 0, 0, 48),
})

local detail = Theme.label(panel, {
	Text = "",
	TextSize = 18,
	Font = Theme.Font,
	Position = UDim2.fromOffset(0, 76),
	Size = UDim2.new(1, 0, 0, 56),
})

local shown = 0

Remotes.GameOver.OnClientEvent:Connect(function(info)
	shown += 1
	local id = shown
	local endsAt = os.clock() + info.Restart
	gui.Enabled = true
	while id == shown and os.clock() < endsAt do
		detail.Text = `You reached wave {info.Wave}.\nRestarting from wave 1 in {math.ceil(endsAt - os.clock())}s`
		task.wait(0.25)
	end
	if id == shown then
		gui.Enabled = false
	end
end)
