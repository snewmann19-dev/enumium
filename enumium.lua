local enumium = {}
enumium.__index = enumium

export type EnumValue = {
	Value: any,
	Name: string,
	EnumType: string,
	Metadata: {[string]: any}?,
	Parent: enumium?,
	IsValid: (self: EnumValue) -> boolean,
	ToString: (self: EnumValue) -> string,
	GetMetadata: (self: EnumValue, key: string) -> any?,
	SetMetadata: (self: EnumValue, key: string, value: any) -> (),
	Clone: (self: EnumValue) -> EnumValue,
	Equals: (self: EnumValue, other: EnumValue) -> boolean,
	Serialize: (self: EnumValue) -> {[string]: any},
	Deserialize: (data: {[string]: any}) -> EnumValue,
}

export type enumium = {
	Name: string,
	Values: {[string]: EnumValue},
	ValueList: {EnumValue},
	Metadata: {[string]: any},
	Plugins: {[string]: any},
	IsValid: (self: enumium) -> boolean,
	GetValue: (self: enumium, name: string) -> EnumValue?,
	GetValueByValue: (self: enumium, value: any) -> EnumValue?,
	AddValue: (self: enumium, name: string, value: any, metadata: {[string]: any}?) -> EnumValue,
	RemoveValue: (self: enumium, name: string) -> boolean,
	HasValue: (self: enumium, name: string) -> boolean,
	HasValueByValue: (self: enumium, value: any) -> boolean,
	GetAllValues: (self: enumium) -> {EnumValue},
	GetAllNames: (self: enumium) -> {string},
	GetAllValuesAsTable: (self: enumium) -> {[string]: any},
	Validate: (self: enumium, value: any) -> boolean,
	ToString: (self: enumium) -> string,
	GetMetadata: (self: enumium, key: string) -> any?,
	SetMetadata: (self: enumium, key: string, value: any) -> (),
	Clone: (self: enumium) -> enumium,
	Equals: (self: enumium, other: enumium) -> boolean,
	Serialize: (self: enumium) -> {[string]: any},
	Deserialize: (data: {[string]: any}) -> enumium,
	RegisterPlugin: (self: enumium, name: string, plugin: any) -> (),
	GetPlugin: (self: enumium, name: string) -> any?,
	ExecutePlugin: (self: enumium, name: string, ...any) -> any,
	Compose: (self: enumium, other: enumium) -> enumium,
	Inherit: (self: enumium, parent: enumium) -> enumium,
	Migrate: (self: enumium, fromVersion: string, toVersion: string) -> enumium,
	GetVersion: (self: enumium) -> string,
	SetVersion: (self: enumium, version: string) -> (),
	Freeze: (self: enumium) -> (),
	IsFrozen: (self: enumium) -> boolean,
	Thaw: (self: enumium) -> (),
	CreateProxy: (self: enumium) -> enumium,
	Watch: (self: enumium, callback: (event: string, data: any) -> ()) -> (),
	Unwatch: (self: enumium, callback: (event: string, data: any) -> ()) -> (),
	Trigger: (self: enumium, event: string, data: any) -> (),
	GetWatchers: (self: enumium) -> {((event: string, data: any) -> ())},
	ClearWatchers: (self: enumium) -> (),
	Performance: (self: enumium) -> {
		GetStats: (self: enumium) -> {[string]: any},
		ResetStats: (self: enumium) -> (),
		Optimize: (self: enumium) -> (),
	},
	Cache: (self: enumium) -> {
		Get: (self: enumium, key: string) -> any?,
		Set: (self: enumium, key: string, value: any) -> (),
		Clear: (self: enumium) -> (),
		Has: (self: enumium, key: string) -> boolean,
		Delete: (self: enumium, key: string) -> boolean,
	},
	Security: (self: enumium) -> {
		SetAccessLevel: (self: enumium, level: string) -> (),
		GetAccessLevel: (self: enumium) -> string,
		RequireAccess: (self: enumium, level: string) -> boolean,
		Encrypt: (self: enumium, key: string) -> string,
		Decrypt: (self: enumium, encrypted: string, key: string) -> enumium?,
	},
}

-- Internal state management
local enumRegistry = {}
local globalPlugins = {}
local performanceStats = {}
local securityKeys = {}

-- Utility functions
local function deepCopy(original)
	local copy = {}
	for key, value in pairs(original) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function generateId()
	return tostring(tick()) .. "_" .. tostring(math.random(1000000, 9999999))
end

local function validateName(name)
	if type(name) ~= "string" or name == "" then
		error("Enum name must be a non-empty string")
	end
	if not string.match(name, "^[%a_][%w_]*$") then
		error("Enum name must start with a letter or underscore and contain only letters, numbers, and underscores")
	end
end

-- EnumValue implementation
local EnumValue = {}
EnumValue.__index = EnumValue

function EnumValue.new(name, value, enumType, metadata, parent)
	validateName(name)

	local self = setmetatable({}, EnumValue)
	self.Name = name
	self.Value = value
	self.EnumType = enumType
	self.Metadata = metadata or {}
	self.Parent = parent
	self._id = generateId()
	self._frozen = false
	self._watchers = {}

	return self
end

function EnumValue:IsValid()
	return self.Name ~= nil and self.Value ~= nil and self.EnumType ~= nil
end

function EnumValue:ToString()
	return string.format("%s.%s = %s", self.EnumType, self.Name, tostring(self.Value))
end

function EnumValue:GetMetadata(key)
	return self.Metadata[key]
end

function EnumValue:SetMetadata(key, value)
	if self._frozen then
		error("Cannot modify frozen enum value")
	end
	self.Metadata[key] = value
	self:Trigger("metadata_changed", {key = key, value = value})
end

function EnumValue:Clone()
	local clone = EnumValue.new(self.Name, deepCopy(self.Value), self.EnumType, deepCopy(self.Metadata), self.Parent)
	clone._frozen = self._frozen
	return clone
end

function EnumValue:Equals(other)
	if not other or getmetatable(other) ~= EnumValue then
		return false
	end
	return self.Name == other.Name and 
		self.Value == other.Value and 
		self.EnumType == other.EnumType
end

function EnumValue:Serialize()
	return {
		name = self.Name,
		value = self.Value,
		enumType = self.EnumType,
		metadata = self.Metadata,
		id = self._id
	}
end

function EnumValue.Deserialize(data)
	local self = EnumValue.new(data.name, data.value, data.enumType, data.metadata)
	self._id = data.id
	return self
end

function EnumValue:Freeze()
	self._frozen = true
end

function EnumValue:IsFrozen()
	return self._frozen
end

function EnumValue:Thaw()
	self._frozen = false
end

function EnumValue:Watch(callback)
	table.insert(self._watchers, callback)
end

function EnumValue:Unwatch(callback)
	for i, watcher in ipairs(self._watchers) do
		if watcher == callback then
			table.remove(self._watchers, i)
			break
		end
	end
end

function EnumValue:Trigger(event, data)
	for _, watcher in ipairs(self._watchers) do
		pcall(watcher, event, data)
	end
end

-- enumium implementation
function enumium.new(name, values, metadata)
	validateName(name)

	local self = setmetatable({}, enumium)
	self.Name = name
	self.Values = {}
	self.ValueList = {}
	self.Metadata = metadata or {}
	self.Plugins = {}
	self._id = generateId()
	self._frozen = false
	self._watchers = {}
	self._version = "1.0.0"
	self._accessLevel = "public"
	self._cache = {}
	self._performanceStats = {
		lookups = 0,
		creations = 0,
		modifications = 0,
		serializations = 0
	}

	-- Initialize with provided values
	if values then
		for name, value in pairs(values) do
			self:AddValue(name, value)
		end
	end

	-- Register in global registry
	enumRegistry[name] = self

	return self
end

function enumium:IsValid()
	return self.Name ~= nil and self.Values ~= nil
end

function enumium:GetValue(name)
	self._performanceStats.lookups = self._performanceStats.lookups + 1
	return self.Values[name]
end

function enumium:GetValueByValue(value)
	self._performanceStats.lookups = self._performanceStats.lookups + 1
	for _, enumValue in pairs(self.Values) do
		if enumValue.Value == value then
			return enumValue
		end
	end
	return nil
end

function enumium:AddValue(name, value, metadata)
	if self._frozen then
		error("Cannot modify frozen enum")
	end

	validateName(name)

	if self.Values[name] then
		error(string.format("Value '%s' already exists in enum '%s'", name, self.Name))
	end

	local enumValue = EnumValue.new(name, value, self.Name, metadata, self)
	self.Values[name] = enumValue
	table.insert(self.ValueList, enumValue)

	self._performanceStats.creations = self._performanceStats.creations + 1
	self:Trigger("value_added", {name = name, value = enumValue})

	return enumValue
end

function enumium:RemoveValue(name)
	if self._frozen then
		error("Cannot modify frozen enum")
	end

	if not self.Values[name] then
		return false
	end

	local enumValue = self.Values[name]
	self.Values[name] = nil

	for i, v in ipairs(self.ValueList) do
		if v == enumValue then
			table.remove(self.ValueList, i)
			break
		end
	end

	self._performanceStats.modifications = self._performanceStats.modifications + 1
	self:Trigger("value_removed", {name = name, value = enumValue})

	return true
end

function enumium:HasValue(name)
	return self.Values[name] ~= nil
end

function enumium:HasValueByValue(value)
	return self:GetValueByValue(value) ~= nil
end

function enumium:GetAllValues()
	return self.ValueList
end

function enumium:GetAllNames()
	local names = {}
	for name, _ in pairs(self.Values) do
		table.insert(names, name)
	end
	return names
end

function enumium:GetAllValuesAsTable()
	local table = {}
	for name, enumValue in pairs(self.Values) do
		table[name] = enumValue.Value
	end
	return table
end

function enumium:Validate(value)
	for _, enumValue in pairs(self.Values) do
		if enumValue.Value == value then
			return true
		end
	end
	return false
end

function enumium:ToString()
	local result = string.format("Enum %s {\n", self.Name)
	for _, enumValue in ipairs(self.ValueList) do
		result = result .. "  " .. enumValue:ToString() .. "\n"
	end
	result = result .. "}"
	return result
end

function enumium:GetMetadata(key)
	return self.Metadata[key]
end

function enumium:SetMetadata(key, value)
	if self._frozen then
		error("Cannot modify frozen enum")
	end
	self.Metadata[key] = value
	self:Trigger("metadata_changed", {key = key, value = value})
end

function enumium:Clone()
	local clone = enumium.new(self.Name .. "_Clone", nil, deepCopy(self.Metadata))
	clone._version = self._version
	clone._accessLevel = self._accessLevel

	for _, enumValue in ipairs(self.ValueList) do
		clone:AddValue(enumValue.Name, deepCopy(enumValue.Value), deepCopy(enumValue.Metadata))
	end

	return clone
end

function enumium:Equals(other)
	if not other or getmetatable(other) ~= enumium then
		return false
	end

	if self.Name ~= other.Name or #self.ValueList ~= #other.ValueList then
		return false
	end

	for _, enumValue in ipairs(self.ValueList) do
		local otherValue = other:GetValue(enumValue.Name)
		if not otherValue or not enumValue:Equals(otherValue) then
			return false
		end
	end

	return true
end

function enumium:Serialize()
	self._performanceStats.serializations = self._performanceStats.serializations + 1

	local data = {
		name = self.Name,
		version = self._version,
		metadata = self.Metadata,
		values = {},
		id = self._id
	}

	for _, enumValue in ipairs(self.ValueList) do
		table.insert(data.values, enumValue:Serialize())
	end

	return data
end

function enumium.Deserialize(data)
	local self = enumium.new(data.name, nil, data.metadata)
	self._version = data.version or "1.0.0"
	self._id = data.id

	for _, valueData in ipairs(data.values) do
		local enumValue = EnumValue.Deserialize(valueData)
		self.Values[enumValue.Name] = enumValue
		table.insert(self.ValueList, enumValue)
	end

	return self
end

-- Plugin system
function enumium:RegisterPlugin(name, plugin)
	if type(plugin) ~= "table" then
		error("Plugin must be a table")
	end

	self.Plugins[name] = plugin
	self:Trigger("plugin_registered", {name = name, plugin = plugin})
end

function enumium:GetPlugin(name)
	return self.Plugins[name]
end

function enumium:ExecutePlugin(name, ...)
	local plugin = self.Plugins[name]
	if not plugin then
		error(string.format("Plugin '%s' not found", name))
	end

	if plugin.execute and type(plugin.execute) == "function" then
		return plugin.execute(self, ...)
	elseif type(plugin) == "function" then
		return plugin(self, ...)
	end

	error(string.format("Plugin '%s' has no valid execute method", name))
end

-- Composition and inheritance
function enumium:Compose(other)
	if not other or getmetatable(other) ~= enumium then
		error("Cannot compose with non-enum")
	end

	local composed = enumium.new(self.Name .. "_" .. other.Name .. "_Composed")

	-- Add values from both enums
	for _, enumValue in ipairs(self.ValueList) do
		composed:AddValue(enumValue.Name, enumValue.Value, enumValue.Metadata)
	end

	for _, enumValue in ipairs(other.ValueList) do
		if not composed:HasValue(enumValue.Name) then
			composed:AddValue(enumValue.Name, enumValue.Value, enumValue.Metadata)
		end
	end

	return composed
end

function enumium:Inherit(parent)
	if not parent or getmetatable(parent) ~= enumium then
		error("Cannot inherit from non-enum")
	end

	local inherited = enumium.new(self.Name .. "_Inherited")

	-- Add parent values first
	for _, enumValue in ipairs(parent.ValueList) do
		inherited:AddValue(enumValue.Name, enumValue.Value, enumValue.Metadata)
	end

	-- Add/override with child values
	for _, enumValue in ipairs(self.ValueList) do
		inherited:AddValue(enumValue.Name, enumValue.Value, enumValue.Metadata)
	end

	return inherited
end

-- Versioning and migration
function enumium:GetVersion()
	return self._version
end

function enumium:SetVersion(version)
	self._version = version
	self:Trigger("version_changed", {version = version})
end

function enumium:Migrate(fromVersion, toVersion)
	-- This is a placeholder for migration logic
	-- In a real implementation, you would define migration rules
	local migrated = self:Clone()
	migrated:SetVersion(toVersion)
	self:Trigger("migrated", {fromVersion = fromVersion, toVersion = toVersion})
	return migrated
end

-- Freezing and thawing
function enumium:Freeze()
	self._frozen = true
	for _, enumValue in ipairs(self.ValueList) do
		enumValue:Freeze()
	end
	self:Trigger("frozen", {})
end

function enumium:IsFrozen()
	return self._frozen
end

function enumium:Thaw()
	self._frozen = false
	for _, enumValue in ipairs(self.ValueList) do
		enumValue:Thaw()
	end
	self:Trigger("thawed", {})
end

-- Proxy system for advanced functionality
function enumium:CreateProxy()
	local proxy = setmetatable({}, {
		__index = function(_, key)
			local value = self:GetValue(key)
			if value then
				return value.Value
			end
			return self[key]
		end,
		__newindex = function(_, key, value)
			if self:HasValue(key) then
				error("Cannot modify enum values through proxy")
			end
			self[key] = value
		end,
		__call = function(_, ...)
			return self:Validate(...)
		end
	})

	return proxy
end

-- Event system
function enumium:Watch(callback)
	table.insert(self._watchers, callback)
end

function enumium:Unwatch(callback)
	for i, watcher in ipairs(self._watchers) do
		if watcher == callback then
			table.remove(self._watchers, i)
			break
		end
	end
end

function enumium:Trigger(event, data)
	for _, watcher in ipairs(self._watchers) do
		pcall(watcher, event, data)
	end
end

function enumium:GetWatchers()
	return self._watchers
end

function enumium:ClearWatchers()
	self._watchers = {}
end

-- Performance monitoring
function enumium:Performance()
	return {
		GetStats = function()
			return deepCopy(self._performanceStats)
		end,
		ResetStats = function()
			self._performanceStats = {
				lookups = 0,
				creations = 0,
				modifications = 0,
				serializations = 0
			}
		end,
		Optimize = function()
			-- Optimize internal data structures
			-- This is a placeholder for optimization logic
			self:Trigger("optimized", {})
		end
	}
end

-- Caching system
function enumium:Cache()
	return {
		Get = function(key)
			return self._cache[key]
		end,
		Set = function(key, value)
			self._cache[key] = value
		end,
		Clear = function()
			self._cache = {}
		end,
		Has = function(key)
			return self._cache[key] ~= nil
		end,
		Delete = function(key)
			local had = self._cache[key] ~= nil
			self._cache[key] = nil
			return had
		end
	}
end

-- Security system
function enumium:Security()
	return {
		SetAccessLevel = function(level)
			self._accessLevel = level
		end,
		GetAccessLevel = function()
			return self._accessLevel
		end,
		RequireAccess = function(level)
			local levels = {public = 1, protected = 2, private = 3}
			return levels[self._accessLevel] >= levels[level]
		end,
		Encrypt = function(key)
			-- Placeholder for encryption
			return "encrypted_" .. self.Name
		end,
		Decrypt = function(encrypted, key)
			-- Placeholder for decryption
			if string.sub(encrypted, 1, 10) == "encrypted_" then
				return self
			end
			return nil
		end
	}
end

-- Global registry functions
function enumium.GetEnum(name)
	return enumRegistry[name]
end

function enumium.GetAllEnums()
	local enums = {}
	for name, enum in pairs(enumRegistry) do
		table.insert(enums, enum)
	end
	return enums
end

function enumium.RegisterGlobalPlugin(name, plugin)
	globalPlugins[name] = plugin
end

function enumium.GetGlobalPlugin(name)
	return globalPlugins[name]
end

-- Built-in plugins
local builtInPlugins = {
	Validation = {
		execute = function(enum, value, strict)
			if strict then
				return enum:Validate(value)
			else
				-- Loose validation - check if value is similar
				for _, enumValue in pairs(enum.Values) do
					if tostring(enumValue.Value) == tostring(value) then
						return true
					end
				end
				return false
			end
		end
	},

	Math = {
		execute = function(enum, operation, ...)
			local args = {...}
			if operation == "sum" then
				local sum = 0
				for _, enumValue in pairs(enum.Values) do
					if type(enumValue.Value) == "number" then
						sum = sum + enumValue.Value
					end
				end
				return sum
			elseif operation == "average" then
				local sum = 0
				local count = 0
				for _, enumValue in pairs(enum.Values) do
					if type(enumValue.Value) == "number" then
						sum = sum + enumValue.Value
						count = count + 1
					end
				end
				return count > 0 and sum / count or 0
			end
		end
	},

	Search = {
		execute = function(enum, query, field)
			local results = {}
			field = field or "name"

			for _, enumValue in pairs(enum.Values) do
				local searchValue = field == "name" and enumValue.Name or tostring(enumValue.Value)
				if string.find(string.lower(searchValue), string.lower(query)) then
					table.insert(results, enumValue)
				end
			end

			return results
		end
	},

	Export = {
		execute = function(enum, format)
			if format == "json" then
				-- Simple JSON-like export
				local result = "{"
				local first = true
				for _, enumValue in pairs(enum.Values) do
					if not first then
						result = result .. ","
					end
					result = result .. string.format('"%s":%s', enumValue.Name, tostring(enumValue.Value))
					first = false
				end
				result = result .. "}"
				return result
			elseif format == "lua" then
				return enum:ToString()
			end
		end
	}
}

-- Register built-in plugins
for name, plugin in pairs(builtInPlugins) do
	enumium.RegisterGlobalPlugin(name, plugin)
end

-- Module exports
return enumium