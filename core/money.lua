-- core/money.lua
-- Multi-source money detection utility
-- Detects player money from leaderstats, attributes, or PlayerGui

local Money = {}

-- Get services (try to use cached services if available)
local function getServices()
    -- Try to get from cached services first
    local success, Services = pcall(function()
        return require(script.Parent.services)
    end)
    
    if success and Services then
        return Services.Players, Services.LocalPlayer
    end
    
    -- Fallback to direct access
    local Players = game:GetService("Players")
    return Players, Players.LocalPlayer
end

-- Common money-related names to search for
local MONEY_NAMES = {
    "Cash", "Money", "Coins", "Gold", "Credits", 
    "Balance", "Bucks", "Dollars", "Currency", "Points"
}

-- Priority 1: Check leaderstats
local function checkLeaderstats(player)
    local success, result = pcall(function()
        local leaderstats = player:FindFirstChild("leaderstats")
        if not leaderstats then
            return nil, nil
        end
        
        for _, name in ipairs(MONEY_NAMES) do
            local currency = leaderstats:FindFirstChild(name)
            if currency and currency:IsA("ValueBase") then
                return currency.Value, "leaderstats." .. name
            end
        end
        
        -- Also check any ValueBase in leaderstats
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("ValueBase") and type(child.Value) == "number" then
                return child.Value, "leaderstats." .. child.Name
            end
        end
        
        return nil, nil
    end)
    
    if success then
        return result
    end
    return nil, nil
end

-- Priority 2: Check Player Attributes
local function checkAttributes(player)
    local success, result = pcall(function()
        -- Check common attribute names
        for _, name in ipairs(MONEY_NAMES) do
            local value = player:GetAttribute(name)
            if value and type(value) == "number" then
                return value, "attribute." .. name
            end
        end
        
        return nil, nil
    end)
    
    if success then
        return result
    end
    return nil, nil
end

-- Priority 3: Check PlayerGui for currency display
local function checkPlayerGui(player)
    local success, result = pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then
            return nil, nil
        end
        
        -- Currency patterns to look for
        local patterns = {"$", "Coins:", "Cash:", "Money:", "Gold:"}
        
        -- Recursive search for TextLabels
        local function searchGui(parent, depth)
            if depth > 5 then return nil, nil end -- Limit depth
            
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("TextLabel") then
                    local text = child.Text
                    
                    -- Check for currency patterns
                    for _, pattern in ipairs(patterns) do
                        if string.find(text, pattern, 1, true) then
                            -- Try to extract number
                            local numStr = string.match(text, "%d[%d,%.]*")
                            if numStr then
                                -- Remove commas and parse
                                numStr = string.gsub(numStr, ",", "")
                                local num = tonumber(numStr)
                                if num then
                                    return num, "gui." .. child.Name
                                end
                            end
                        end
                    end
                end
                
                -- Recurse into children
                local val, source = searchGui(child, depth + 1)
                if val then
                    return val, source
                end
            end
            
            return nil, nil
        end
        
        return searchGui(playerGui, 0)
    end)
    
    if success then
        return result
    end
    return nil, nil
end

-- Main function: Get player's money amount
-- Returns: amount (number), source (string describing where found)
function Money.getPlayerMoney()
    local success, amount, source = pcall(function()
        local _, player = getServices()
        if not player then
            return 0, "no_player"
        end
        
        -- Priority 1: leaderstats
        local val, src = checkLeaderstats(player)
        if val then
            return val, src
        end
        
        -- Priority 2: Attributes
        val, src = checkAttributes(player)
        if val then
            return val, src
        end
        
        -- Priority 3: PlayerGui
        val, src = checkPlayerGui(player)
        if val then
            return val, src
        end
        
        return 0, "unknown"
    end)
    
    if success then
        return amount, source
    else
        warn("[Money] getPlayerMoney failed: " .. tostring(amount))
        return 0, "error"
    end
end

-- Helper: Check if player can afford a price
function Money.canAfford(price)
    local success, result = pcall(function()
        if not price or type(price) ~= "number" then
            return false
        end
        
        local amount = Money.getPlayerMoney()
        return amount >= price
    end)
    
    if success then
        return result
    else
        warn("[Money] canAfford failed: " .. tostring(result))
        return false
    end
end

-- Optional: Watch for money changes
-- callback: function(newAmount, source)
-- Returns: connection (call :Disconnect() to stop watching)
function Money.watchMoney(callback)
    local success, connection = pcall(function()
        local _, player = getServices()
        if not player then
            return nil
        end
        
        local leaderstats = player:FindFirstChild("leaderstats")
        if not leaderstats then
            -- Try to wait for leaderstats (with timeout)
            local waitSuccess, result = pcall(function()
                return player:WaitForChild("leaderstats", 5)
            end)
            if waitSuccess and result then
                leaderstats = result
            end
        end
        
        if not leaderstats then
            warn("[Money] watchMoney: No leaderstats found")
            return nil
        end
        
        -- Find the first currency value
        for _, name in ipairs(MONEY_NAMES) do
            local currency = leaderstats:FindFirstChild(name)
            if currency and currency:IsA("ValueBase") then
                return currency:GetPropertyChangedSignal("Value"):Connect(function()
                    local amount = currency.Value
                    local source = "leaderstats." .. name
                    callback(amount, source)
                end)
            end
        end
        
        -- Check any ValueBase
        for _, child in ipairs(leaderstats:GetChildren()) do
            if child:IsA("ValueBase") and type(child.Value) == "number" then
                return child:GetPropertyChangedSignal("Value"):Connect(function()
                    local amount = child.Value
                    local source = "leaderstats." .. child.Name
                    callback(amount, source)
                end)
            end
        end
        
        warn("[Money] watchMoney: No currency value found in leaderstats")
        return nil
    end)
    
    if success then
        return connection
    else
        warn("[Money] watchMoney failed: " .. tostring(connection))
        return nil
    end
end

-- Debug: Print current money detection result
function Money.debug()
    local amount, source = Money.getPlayerMoney()
    print(string.format("[Money] Amount: %d, Source: %s", amount, source))
    return amount, source
end

return Money
