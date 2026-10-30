--!strict
-- Collects connections, instances and callbacks so they can be released together.
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({
		_tasks = {},
	}, Maid)
end

function Maid:Give(task: any)
	table.insert(self._tasks, task)
	return task
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for _, item in tasks do
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			item:Destroy()
		elseif kind == "function" then
			item()
		elseif kind == "table" and type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif kind == "table" and type(item.Destroy) == "function" then
			item:Destroy()
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
