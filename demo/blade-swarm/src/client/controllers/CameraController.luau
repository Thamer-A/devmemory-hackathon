--!nonstrict
-- Pulls the default follow camera back so the whole swarm stays in view.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CameraController = {}

local localPlayer = Players.LocalPlayer

function CameraController.init()
	localPlayer.CameraMode = Enum.CameraMode.Classic
end

function CameraController.start()
	-- Set max first so min can never exceed it.
	localPlayer.CameraMaxZoomDistance = Config.CameraMaxZoom
	localPlayer.CameraMinZoomDistance = Config.CameraMinZoom
end

return CameraController
