--!strict
local Log = {}

local function format(tag: string, ...: any): string
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	return string.format("[%s] %s", tag, table.concat(parts, " ", 1, parts.n))
end

function Log.info(tag: string, ...: any)
	print(format(tag, ...))
end

function Log.warn(tag: string, ...: any)
	warn(format(tag, ...))
end

function Log.error(tag: string, ...: any)
	warn(format(tag, ...))
	task.defer(error, format(tag, ...), 0)
end

return Log
