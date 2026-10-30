local ContextActionService = game:GetService("ContextActionService")

local UIController = require(script.Parent.UIController)

local InputController = {}

local ACTION_SHOP = "CoinRush_ToggleShop"
local ACTION_INVENTORY = "CoinRush_ToggleInventory"

local function makeHandler(panelName: string)
	return function(_actionName: string, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			UIController.toggle(panelName)
		end
		return Enum.ContextActionResult.Sink
	end
end

function InputController.init()
	ContextActionService:BindAction(ACTION_SHOP, makeHandler("Shop"), false, Enum.KeyCode.E)
	ContextActionService:BindAction(ACTION_INVENTORY, makeHandler("Inventory"), false, Enum.KeyCode.I)
end

function InputController.start()
	-- Controllers can be torn down on character reset in some setups; nothing to rebind here.
end

return InputController
