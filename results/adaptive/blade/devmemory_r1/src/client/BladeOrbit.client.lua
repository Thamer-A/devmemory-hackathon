-- Moves every player's blades locally each frame. Blade phase derives from the
-- synced server clock, so all clients (and the server) agree on positions.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config).Blades
local BladeMath = require(game.ReplicatedStorage.Shared.BladeMath)

local bladesRoot = workspace:WaitForChild("Blades")

RunService.RenderStepped:Connect(function()
	local t = workspace:GetServerTimeNow()
	for _, folder in bladesRoot:GetChildren() do
		local player = Players:GetPlayerByUserId(tonumber(folder.Name) or 0)
		local hrp = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			continue
		end

		local reach = player:GetAttribute("Reach") or 0
		local spin = Config.SpinSpeed * (player:GetAttribute("SpinMult") or 1)
		local blades = folder:GetChildren()
		local count = #blades
		for _, blade in blades do
			local i = blade:GetAttribute("Index")
			if not i then
				continue
			end
			local offset, angle = BladeMath.getOffset(i, count, t, reach)
			local pos = hrp.Position + offset
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			blade.CFrame = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, t * spin + i)
		end
	end
end)
