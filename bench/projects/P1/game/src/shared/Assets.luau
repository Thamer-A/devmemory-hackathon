--!strict
local Log = require(script.Parent.Log)

local manifest: { [string]: string } = require(script.Parent.AssetManifest)

local Assets = {}

function Assets.get(name: string): string?
	local id = manifest[name]
	if id == nil then
		Log.warn("Assets", "missing asset", name)
		return nil
	end
	return id
end

-- Numeric portion of an asset id, for APIs such as InsertService:LoadAsset.
function Assets.getNumericId(name: string): number?
	local id = Assets.get(name)
	if id == nil then
		return nil
	end
	local digits = string.match(id, "%d+")
	return if digits then tonumber(digits) else nil
end

function Assets.has(name: string): boolean
	return manifest[name] ~= nil
end

return Assets
