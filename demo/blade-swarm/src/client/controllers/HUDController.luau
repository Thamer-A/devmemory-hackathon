--!nonstrict
-- Heads-up display: wave pill, coins, health bar, stats chips and the phase banner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Maid = require(Shared.Maid)
local MathUtil = require(Shared.MathUtil)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local HUDController = {}

local localPlayer = Players.LocalPlayer
local colors = Theme.Colors

local STAT_CHIPS = {
	{
		icon = "🗡️",
		name = "Blades",
		value = function(stats)
			return tostring(stats.BladeCount)
		end,
	},
	{
		icon = "💥",
		name = "Damage",
		value = function(stats)
			return tostring(math.floor(stats.BladeDamage + 0.5))
		end,
	},
	{
		icon = "📏",
		name = "Reach",
		value = function(stats)
			return string.format("%.0f", stats.BladeRadius)
		end,
	},
	{
		icon = "👟",
		name = "Speed",
		value = function(stats)
			return string.format("%.0f", stats.WalkSpeed)
		end,
	},
	{
		icon = "🧛",
		name = "Lifesteal",
		optional = function(stats)
			return stats.Lifesteal > 0
		end,
		value = function(stats)
			return "+" .. string.format("%.0f", stats.Lifesteal)
		end,
	},
	{
		icon = "💰",
		name = "Coin bonus",
		optional = function(stats)
			return stats.CoinBonus > 0
		end,
		value = function(stats)
			return "+" .. string.format("%.0f", stats.CoinBonus * 100) .. "%"
		end,
	},
}

-- UI references
local gui: ScreenGui
local waveLabel: TextLabel
local timerLabel: TextLabel
local zombieLabel: TextLabel
local coinPanel: Frame
local coinLabel: TextLabel
local healthPanel: Frame
local healthFill: Frame
local healthLabel: TextLabel
local bannerLabel: TextLabel
local bannerStroke: UIStroke
local subStroke: UIStroke
local bannerScale: UIScale
local subLabel: TextLabel
local chips = {}

-- State
local phase = "Waiting"
local wave = 1
local endsAt = 0
local zombiesLeft = 0
local coinsTarget = 0
local coinsShown = 0
local lastTimerText = ""
local lastBannerKey = ""
local bannerToken = 0
local pendingSub: string? = nil
local characterMaid = Maid.new()

local function healthColor(fraction: number): Color3
	if fraction > 0.5 then
		return colors.Warn:Lerp(colors.Good, (fraction - 0.5) * 2)
	end
	return colors.Danger:Lerp(colors.Warn, fraction * 2)
end

-- Construction -------------------------------------------------------------

local function buildWavePill()
	local pill = Theme.panel(gui, {
		Name = "WavePill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromScale(0.32, 0.07),
	})
	Theme.new("UISizeConstraint", { MinSize = Vector2.new(300, 44), MaxSize = Vector2.new(480, 64) }, pill)
	Theme.corner(pill, 28)

	waveLabel = Theme.label(pill, {
		Name = "Wave",
		Position = UDim2.fromScale(0.05, 0.1),
		Size = UDim2.fromScale(0.31, 0.8),
		FontFace = Theme.Fonts.Title,
		Text = "WAVE 1",
		TextColor3 = colors.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.textSizeLimit(waveLabel, 10, 28)

	timerLabel = Theme.label(pill, {
		Name = "Timer",
		Position = UDim2.fromScale(0.37, 0.1),
		Size = UDim2.fromScale(0.26, 0.8),
		FontFace = Theme.Fonts.Title,
		Text = "0:00",
		TextColor3 = colors.Accent,
		TextScaled = true,
	})
	Theme.textSizeLimit(timerLabel, 10, 28)

	zombieLabel = Theme.label(pill, {
		Name = "Zombies",
		Position = UDim2.fromScale(0.64, 0.1),
		Size = UDim2.fromScale(0.31, 0.8),
		FontFace = Theme.Fonts.Title,
		Text = "",
		TextColor3 = colors.Good,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	Theme.textSizeLimit(zombieLabel, 10, 28)

	for _, x in { 0.365, 0.635 } do
		Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.new(0, 2, 0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
		}, pill)
	end
end

local function buildCoins()
	coinPanel = Theme.panel(gui, {
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromScale(0.13, 0.065),
	})
	Theme.new("UISizeConstraint", { MinSize = Vector2.new(120, 38), MaxSize = Vector2.new(210, 54) }, coinPanel)
	Theme.corner(coinPanel, 24)
	Theme.stroke(coinPanel, colors.Gold, 1.5, 0.6)

	-- drawn coin icon (the coin emoji does not render in Roblox's font)
	local coin = Theme.new("Frame", {
		Name = "CoinIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromScale(0.62, 0.62),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = colors.Gold,
	}, coinPanel)
	Theme.corner(coin, 999)
	Theme.new("UIStroke", { Color = Color3.fromRGB(176, 120, 20), Thickness = 2 }, coin)

	coinLabel = Theme.label(coinPanel, {
		Size = UDim2.new(1, -54, 0.8, 0),
		Position = UDim2.new(0, 44, 0.1, 0),
		FontFace = Theme.Fonts.Title,
		Text = "0",
		TextColor3 = colors.Gold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.textSizeLimit(coinLabel, 10, 28)
end

local function buildHealth()
	healthPanel = Theme.panel(gui, {
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromScale(0.34, 0.05),
		Visible = false,
	})
	Theme.new("UISizeConstraint", { MinSize = Vector2.new(260, 26), MaxSize = Vector2.new(540, 44) }, healthPanel)
	Theme.corner(healthPanel, 20)

	local track = Theme.new("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = Color3.fromHex("0b0e16"),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, healthPanel)
	Theme.corner(track, 16)

	healthFill = Theme.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = colors.Good,
		BorderSizePixel = 0,
	}, track)
	Theme.corner(healthFill, 16)
	Theme.gradient(healthFill, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170), 90)

	healthLabel = Theme.label(healthPanel, {
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.Fonts.Title,
		Text = "100 / 100",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		ZIndex = 3,
	})
	Theme.textSizeLimit(healthLabel, 10, 22)
	Theme.new("UIPadding", { PaddingTop = UDim.new(0.15, 0), PaddingBottom = UDim.new(0.15, 0) }, healthLabel)
	Theme.new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = 2,
		Transparency = 0.4,
	}, healthLabel)
end

local function buildChips()
	local holder = Theme.new("Frame", {
		Name = "Chips",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0.14, 0, 0.5, 0),
		BackgroundTransparency = 1,
	}, gui)
	Theme.new("UISizeConstraint", { MinSize = Vector2.new(150, 0), MaxSize = Vector2.new(210, 400) }, holder)
	Theme.new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 6),
	}, holder)

	for index, def in STAT_CHIPS do
		local chip = Theme.panel(holder, {
			Name = def.name,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 30),
		})
		Theme.corner(chip, 10)
		local name = Theme.label(chip, {
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(0.65, 0, 1, 0),
			Text = def.icon .. " " .. def.name,
			TextSize = 14,
			TextColor3 = colors.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		name.FontFace = Theme.Fonts.Bold
		local value = Theme.label(chip, {
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(0.5, -10, 1, 0),
			FontFace = Theme.Fonts.Title,
			Text = "0",
			TextSize = 18,
			TextColor3 = colors.Text,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		chips[index] = { frame = chip, value = value, def = def }
	end
end

local function buildBanner()
	bannerLabel = Theme.label(gui, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.28),
		Size = UDim2.fromScale(0.6, 0.16),
		FontFace = Theme.Fonts.Title,
		Text = "",
		TextScaled = true,
		TextTransparency = 1,
		ZIndex = 5,
	})
	Theme.textSizeLimit(bannerLabel, 20, 110)
	bannerStroke = Theme.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 4, Transparency = 1 }, bannerLabel)
	bannerScale = Theme.scaleOf(bannerLabel, "BannerScale")

	subLabel = Theme.label(gui, {
		Name = "BannerSub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromScale(0.5, 0.045),
		FontFace = Theme.Fonts.Bold,
		Text = "",
		TextScaled = true,
		TextColor3 = colors.Text,
		TextTransparency = 1,
		ZIndex = 5,
	})
	Theme.textSizeLimit(subLabel, 12, 28)
	-- the outline must fade with the text, otherwise a black outline-only ghost stays on screen
	subStroke = Theme.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 1 }, subLabel)
end

-- Behaviour ----------------------------------------------------------------

local function showBanner(text: string, color: Color3, sub: string?)
	bannerToken += 1
	local token = bannerToken

	bannerLabel.Text = text
	bannerLabel.TextColor3 = color
	bannerLabel.TextTransparency = 1
	bannerStroke.Transparency = 1
	bannerScale.Scale = 0.5
	subLabel.Text = sub or ""
	subLabel.TextTransparency = 1
	subStroke.Transparency = 1

	Theme.tween(bannerScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Theme.tween(bannerLabel, 0.2, { TextTransparency = 0 })
	Theme.tween(bannerStroke, 0.2, { Transparency = 0.2 })
	if sub then
		Theme.tween(subLabel, 0.3, { TextTransparency = 0 })
		Theme.tween(subStroke, 0.3, { Transparency = 0.4 })
	end

	task.delay(1.9, function()
		if token ~= bannerToken then
			return
		end
		Theme.tween(bannerScale, 0.5, { Scale = 1.2 })
		Theme.tween(bannerLabel, 0.5, { TextTransparency = 1 })
		Theme.tween(bannerStroke, 0.5, { Transparency = 1 })
		Theme.tween(subLabel, 0.5, { TextTransparency = 1 })
		Theme.tween(subStroke, 0.5, { Transparency = 1 })
	end)
end

local function updateHealth()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		healthPanel.Visible = false
		return
	end
	healthPanel.Visible = true
	local maxHealth = math.max(1, humanoid.MaxHealth)
	local health = math.clamp(humanoid.Health, 0, maxHealth)
	local fraction = health / maxHealth
	healthLabel.Text = string.format("%d / %d", math.ceil(health), math.floor(maxHealth + 0.5))
	Theme.tween(healthFill, 0.25, { Size = UDim2.fromScale(fraction, 1), BackgroundColor3 = healthColor(fraction) })
end

local function bindCharacter(character: Model)
	characterMaid:Clean()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil then
		return
	end
	characterMaid:Give(humanoid.HealthChanged:Connect(updateHealth))
	characterMaid:Give(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth))
	updateHealth()
end

local function phaseTitle(): string
	if phase == "Wave" then
		return "WAVE " .. wave
	elseif phase == "Shop" then
		return "SHOP"
	elseif phase == "GameOver" then
		return "GAME OVER"
	end
	return "GET READY"
end

local function renderState()
	waveLabel.Text = phaseTitle()
	if phase == "Wave" then
		zombieLabel.Text = "🧟 " .. zombiesLeft
	else
		zombieLabel.Text = ""
	end
end

local function onStateChanged(newPhase: string, newWave: number, newEndsAt: number, left: number)
	phase = newPhase
	wave = newWave
	endsAt = newEndsAt
	zombiesLeft = left
	renderState()

	local key = newPhase .. newWave
	if key == lastBannerKey then
		return
	end
	lastBannerKey = key

	if newPhase == "Wave" then
		showBanner("WAVE " .. newWave, colors.Gold, if newWave == 1 then "Survive the swarm!" else nil)
	elseif newPhase == "Shop" then
		showBanner("SHOP", colors.Accent, "Pick your upgrades")
	elseif newPhase == "GameOver" then
		showBanner("GAME OVER", colors.Danger, pendingSub)
		pendingSub = nil
	end
end

local function onStatsChanged(stats, coins: number)
	if coins > coinsTarget then
		Theme.punch(coinPanel, 1.08)
	end
	coinsTarget = coins
	for _, chip in chips do
		local visible = chip.def.optional == nil or chip.def.optional(stats)
		chip.frame.Visible = visible
		if visible then
			local text = chip.def.value(stats)
			if chip.value.Text ~= text then
				chip.value.Text = text
				Theme.punch(chip.frame, 1.06)
			end
		end
	end
end

local function onHeartbeat(dt: number)
	if coinsShown ~= coinsTarget then
		coinsShown += (coinsTarget - coinsShown) * math.min(1, dt * 8)
		if math.abs(coinsTarget - coinsShown) < 0.5 then
			coinsShown = coinsTarget
		end
		coinLabel.Text = MathUtil.formatNumber(coinsShown)
	end

	local text
	if phase == "Waiting" and endsAt <= 0 then
		text = "..."
	else
		text = MathUtil.formatClock(endsAt - workspace:GetServerTimeNow())
	end
	if text ~= lastTimerText then
		lastTimerText = text
		timerLabel.Text = text
	end
end

function HUDController.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	gui = Theme.new("ScreenGui", {
		Name = "BladeSwarmHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	buildWavePill()
	buildCoins()
	buildHealth()
	buildChips()
	buildBanner()
end

function HUDController.start()
	Remotes.get("StateChanged").OnClientEvent:Connect(onStateChanged)
	Remotes.get("StatsChanged").OnClientEvent:Connect(onStatsChanged)
	Remotes.get("RunReset").OnClientEvent:Connect(function(reached: number)
		pendingSub = "You reached wave " .. tostring(reached)
	end)

	RunService.Heartbeat:Connect(onHeartbeat)

	localPlayer.CharacterAdded:Connect(bindCharacter)
	localPlayer.CharacterRemoving:Connect(function()
		characterMaid:Clean()
		healthPanel.Visible = false
	end)
	if localPlayer.Character then
		task.spawn(bindCharacter, localPlayer.Character)
	end

	renderState()
end

return HUDController
