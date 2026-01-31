-- config/egg-types.lua
-- Egg mutation types configuration
-- Easily updatable table of known mutation types and their base prices

local EggTypes = {}

-- Default known mutation types
-- Format: {name = "DisplayName", price = basePrice}
-- Prices are estimates - will be validated in-game
EggTypes.Types = {
    {name = "Normal", price = 100},
    {name = "Shiny", price = 500},
    {name = "Electric", price = 1000},
    {name = "Christmas", price = 2500},
    {name = "Radioactive", price = 5000},
    {name = "Mythic", price = 10000},
}

-- Internal lookup cache (built on first use)
local lookupCache = nil

-- Build lookup cache for fast access
local function buildLookup()
    if lookupCache then return lookupCache end
    
    lookupCache = {}
    for _, entry in ipairs(EggTypes.Types) do
        -- Store with lowercase key for case-insensitive lookup
        lookupCache[string.lower(entry.name)] = entry
    end
    return lookupCache
end

-- Get array of mutation names (for UI dropdown)
function EggTypes.getNames()
    local success, result = pcall(function()
        local names = {}
        for _, entry in ipairs(EggTypes.Types) do
            table.insert(names, entry.name)
        end
        return names
    end)
    
    if success then
        return result
    else
        warn("[EggTypes] getNames failed: " .. tostring(result))
        return {}
    end
end

-- Get price for a mutation type (case-insensitive)
function EggTypes.getPrice(name)
    local success, result = pcall(function()
        if not name or type(name) ~= "string" then
            return 0
        end
        
        local lookup = buildLookup()
        local entry = lookup[string.lower(name)]
        
        if entry then
            return entry.price
        end
        return 0
    end)
    
    if success then
        return result
    else
        warn("[EggTypes] getPrice failed: " .. tostring(result))
        return 0
    end
end

-- Check if mutation name is valid (case-insensitive)
function EggTypes.isValid(name)
    local success, result = pcall(function()
        if not name or type(name) ~= "string" then
            return false
        end
        
        local lookup = buildLookup()
        return lookup[string.lower(name)] ~= nil
    end)
    
    if success then
        return result
    else
        warn("[EggTypes] isValid failed: " .. tostring(result))
        return false
    end
end

-- Add custom mutation type (for future updates)
function EggTypes.addType(name, price)
    local success, err = pcall(function()
        if not name or type(name) ~= "string" then
            error("Invalid name")
        end
        if not price or type(price) ~= "number" then
            error("Invalid price")
        end
        
        -- Check if already exists
        if EggTypes.isValid(name) then
            -- Update existing
            local lookup = buildLookup()
            lookup[string.lower(name)].price = price
            print("[EggTypes] Updated: " .. name .. " = $" .. tostring(price))
        else
            -- Add new
            local entry = {name = name, price = price}
            table.insert(EggTypes.Types, entry)
            -- Invalidate cache so it rebuilds
            lookupCache = nil
            print("[EggTypes] Added: " .. name .. " = $" .. tostring(price))
        end
    end)
    
    if not success then
        warn("[EggTypes] addType failed: " .. tostring(err))
        return false
    end
    return true
end

-- Get all types as array (for iteration)
function EggTypes.getAll()
    local success, result = pcall(function()
        local all = {}
        for _, entry in ipairs(EggTypes.Types) do
            table.insert(all, {name = entry.name, price = entry.price})
        end
        return all
    end)
    
    if success then
        return result
    else
        warn("[EggTypes] getAll failed: " .. tostring(result))
        return {}
    end
end

return EggTypes
