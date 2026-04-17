-- LibDataBroker-1.1
-- A central registry for data provider addons (launchers, data sources, etc.)
-- License: Public Domain

local MAJOR, MINOR = "LibDataBroker-1.1", 4
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.attributestorage = lib.attributestorage or {}
lib.namestorage = lib.namestorage or {}
lib.proxystorage = lib.proxystorage or {}

local attributestorage = lib.attributestorage
local namestorage = lib.namestorage
local proxystorage = lib.proxystorage
local callbacks = lib.callbacks

function lib:DataObjectIterator()
    return pairs(attributestorage)
end

function lib:GetDataObjectByName(dataobjectname)
    return proxystorage[dataobjectname]
end

function lib:GetNameByDataObject(dataobject)
    return namestorage[dataobject]
end

local function newProxy(name)
    local dataobj = {}
    attributestorage[dataobj] = {}
    namestorage[dataobj] = name
    proxystorage[name] = dataobj

    local mt = {
        __index = function(self, key)
            return attributestorage[self] and attributestorage[self][key]
        end,
        __newindex = function(self, key, value)
            if not attributestorage[self] then attributestorage[self] = {} end
            attributestorage[self][key] = value
            callbacks:Fire("LibDataBroker_AttributeChanged_" .. name .. "_" .. key, name, key, value, self)
            callbacks:Fire("LibDataBroker_AttributeChanged", name, key, value, self)
        end,
    }
    setmetatable(dataobj, mt)
    return dataobj
end

function lib:NewDataObject(name, dataobj)
    if proxystorage[name] then return end

    local proxy = newProxy(name)
    if dataobj then
        for k, v in pairs(dataobj) do
            proxy[k] = v
        end
    end
    callbacks:Fire("LibDataBroker_DataObjectCreated", name, proxy)
    return proxy
end
