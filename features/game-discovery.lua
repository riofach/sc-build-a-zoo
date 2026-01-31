-- Build A Zoo Script - Game Discovery Module
-- Discovers player folder, animals, money state, and RemoteEvents
-- Uses multiple patterns for robustness across game updates

-- Get Services (passed via loadModule or fallback)
local Services = nil
local function getServices()
    if Services then return Services end
    
    -- Try to get from global loader or direct load
    local success, result = pcall(function()
        return {
            Workspace = game:GetService("Workspace"),
            Players = game:GetService("Players"),
            ReplicatedStorage = game:GetService("ReplicatedStorage"),
            LocalPlayer = game:GetService("Players").LocalPlayer
        }
    end)
    
    if success then
        Services = result
    else
        warn("[Discovery] Failed to get services: " .. tostring(result))
        Services = {}
    end
    
    return Services
end

-- Common animal name patterns for detection
local ANIMAL_PATTERNS = {
    "Lion", "Tiger", "Elephant", "Giraffe", "Zebra", "Monkey", "Gorilla",
    "Bear", "Wolf", "Fox", "Deer", "Rabbit", "Penguin", "Flamingo",
    "Parrot", "Eagle", "Owl", "Snake", "Crocodile", "Hippo", "Rhino",
    "Panda", "Koala", "Kangaroo", "Dolphin", "Shark", "Whale", "Turtle",
    "Animal" -- Generic pattern
}

-- Discovery module
local Discovery = {}

-- ============================================================================
-- findPlayerFolder()
-- Finds the player's folder in Workspace using multiple common patterns
-- Returns: Instance or nil
-- ============================================================================
local function findPlayerFolder()
    local services = getServices()
    
    if not services.Workspace or not services.LocalPlayer then
        warn("[Discovery] Services not available for player folder discovery")
        return nil
    end
    
    local playerName = services.LocalPlayer.Name
    local userId = tostring(services.LocalPlayer.UserId)
    
    -- Patterns to try (in order of likelihood)
    local patterns = {
        { parent = services.Workspace, name = playerName },
        { parent = services.Workspace, name = userId },
        { parent = services.Workspace, child = "PlayerObjects", name = playerName },
        { parent = services.Workspace, child = "Zoos", name = playerName },
        { parent = services.Workspace, child = "PlayerZoos", name = playerName },
        { parent = services.Workspace, child = "PlayerAreas", name = playerName },
        { parent = services.Workspace, child = "PlayerObjects", name = userId },
        { parent = services.Workspace, child = "Zoos", name = userId },
    }
    
    for i, pattern in ipairs(patterns) do
        local success, result = pcall(function()
            local searchParent = pattern.parent
            
            -- If there's an intermediate child folder, navigate to it first
            if pattern.child then
                local childFolder = searchParent:FindFirstChild(pattern.child)
                if not childFolder then
                    return nil
                end
                searchParent = childFolder
            end
            
            -- Look for player's folder
            local playerFolder = searchParent:FindFirstChild(pattern.name)
            return playerFolder
        end)
        
        if success and result then
            local pathDesc = pattern.child 
                and string.format("Workspace.%s.%s", pattern.child, pattern.name)
                or string.format("Workspace.%s", pattern.name)
            print("[Discovery] Found player folder at: " .. pathDesc)
            return result
        end
    end
    
    warn("[Discovery] Could not find player folder using any known pattern")
    return nil
end

-- ============================================================================
-- isAnimalModel(instance)
-- Checks if an instance is likely an animal model
-- Returns: boolean
-- ============================================================================
local function isAnimalModel(instance)
    if not instance or not instance:IsA("Model") then
        return false
    end
    
    -- Pattern 1: Has "Animal" or "AnimalData" child
    local success1, hasAnimalChild = pcall(function()
        return instance:FindFirstChild("Animal") ~= nil 
            or instance:FindFirstChild("AnimalData") ~= nil
    end)
    if success1 and hasAnimalChild then
        return true
    end
    
    -- Pattern 2: Has "IsAnimal" attribute set to true
    local success2, isAnimalAttr = pcall(function()
        return instance:GetAttribute("IsAnimal") == true
    end)
    if success2 and isAnimalAttr then
        return true
    end
    
    -- Pattern 3: Name contains animal patterns
    local success3, nameMatch = pcall(function()
        local name = instance.Name
        for _, pattern in ipairs(ANIMAL_PATTERNS) do
            if string.find(name, pattern, 1, true) then
                return true
            end
        end
        return false
    end)
    if success3 and nameMatch then
        return true
    end
    
    return false
end

-- ============================================================================
-- findPlayerAnimals()
-- Finds all animal instances belonging to the player
-- Returns: table of Instance (never nil, returns empty table if none found)
-- ============================================================================
local function findPlayerAnimals()
    local animals = {}
    
    local playerFolder = findPlayerFolder()
    if not playerFolder then
        warn("[Discovery] No player folder found, cannot search for animals")
        return animals
    end
    
    -- Get all descendants safely
    local success, descendants = pcall(function()
        return playerFolder:GetDescendants()
    end)
    
    if not success then
        warn("[Discovery] Failed to get descendants: " .. tostring(descendants))
        return animals
    end
    
    -- Check for "Animals" folder pattern first
    local animalsFolder = nil
    local folderSuccess, folderResult = pcall(function()
        return playerFolder:FindFirstChild("Animals") or playerFolder:FindFirstChild("MyAnimals")
    end)
    
    if folderSuccess and folderResult then
        animalsFolder = folderResult
        print("[Discovery] Found dedicated Animals folder: " .. animalsFolder.Name)
        
        -- Add all children of Animals folder as animals
        local childSuccess, children = pcall(function()
            return animalsFolder:GetChildren()
        end)
        
        if childSuccess then
            for _, child in ipairs(children) do
                if child:IsA("Model") then
                    table.insert(animals, child)
                end
            end
        end
    end
    
    -- Also check all descendants for animal models
    for _, descendant in ipairs(descendants) do
        -- Skip if already added from Animals folder
        local alreadyAdded = false
        for _, existing in ipairs(animals) do
            if existing == descendant then
                alreadyAdded = true
                break
            end
        end
        
        if not alreadyAdded and isAnimalModel(descendant) then
            table.insert(animals, descendant)
        end
    end
    
    print("[Discovery] Found " .. #animals .. " animals")
    return animals
end

-- ============================================================================
-- isMoneyReady(animal)
-- Checks if an animal has money ready to collect
-- Returns: boolean (ready), number (amount, can be 0)
-- ============================================================================
local function isMoneyReady(animal)
    if not animal then
        return false, 0
    end
    
    local amount = 0
    
    -- Pattern 1: NumberValue/IntValue child with money-related names
    local moneyValueNames = {"Money", "Cash", "Coins", "CollectableMoney", "ReadyMoney", "Income"}
    for _, valueName in ipairs(moneyValueNames) do
        local success, result = pcall(function()
            local valueObj = animal:FindFirstChild(valueName)
            if valueObj and (valueObj:IsA("NumberValue") or valueObj:IsA("IntValue")) then
                return valueObj.Value
            end
            return nil
        end)
        
        if success and result and result > 0 then
            return true, result
        end
    end
    
    -- Pattern 2: Attributes with money values
    local moneyAttrs = {"Money", "CollectableMoney", "ReadyMoney", "Cash", "Coins", "Income"}
    for _, attrName in ipairs(moneyAttrs) do
        local success, result = pcall(function()
            return animal:GetAttribute(attrName)
        end)
        
        if success and type(result) == "number" and result > 0 then
            return true, result
        end
    end
    
    -- Pattern 3: BillboardGui enabled (visual money indicator)
    local success3, hasBillboard = pcall(function()
        for _, child in ipairs(animal:GetChildren()) do
            if child:IsA("BillboardGui") and child.Enabled then
                -- Check if it has money-related content
                local label = child:FindFirstChildOfClass("TextLabel")
                if label and label.Text and (
                    string.find(label.Text, "$", 1, true) or
                    string.find(label.Text, "Collect", 1, true) or
                    string.find(label.Text, "Ready", 1, true)
                ) then
                    return true
                end
            end
        end
        return false
    end)
    
    if success3 and hasBillboard then
        return true, amount
    end
    
    -- Pattern 4: Part child with money indicator names
    local indicatorNames = {"MoneyDrop", "CoinDrop", "MoneyIndicator", "CashDrop", "CollectIndicator"}
    for _, indicatorName in ipairs(indicatorNames) do
        local success, result = pcall(function()
            local indicator = animal:FindFirstChild(indicatorName)
            if indicator and indicator:IsA("BasePart") then
                return indicator.Transparency < 1 -- Visible = money ready
            end
            return false
        end)
        
        if success and result then
            return true, amount
        end
    end
    
    return false, 0
end

-- ============================================================================
-- findCollectRemote()
-- Finds RemoteEvent/RemoteFunction for collecting money
-- Returns: Instance or nil
-- ============================================================================
local function findCollectRemote()
    local services = getServices()
    
    if not services.ReplicatedStorage then
        warn("[Discovery] ReplicatedStorage not available")
        return nil
    end
    
    -- Patterns to search for (ordered by likelihood)
    local remotePatterns = {
        "Collect", "CollectMoney", "CollectCash", "CollectAll", "CollectAnimalMoney",
        "Claim", "ClaimMoney", "ClaimReward", "ClaimAll", "ClaimAnimal",
        "GatherMoney", "PickupMoney", "GetMoney", "TakeMoney",
        "AnimalCollect", "ZooCollect", "MoneyCollect"
    }
    
    -- Get all descendants of ReplicatedStorage
    local success, descendants = pcall(function()
        return services.ReplicatedStorage:GetDescendants()
    end)
    
    if not success then
        warn("[Discovery] Failed to get ReplicatedStorage descendants: " .. tostring(descendants))
        return nil
    end
    
    -- Log all RemoteEvents/RemoteFunctions for debugging
    local foundRemotes = {}
    for _, descendant in ipairs(descendants) do
        local isRemote = descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")
        if isRemote then
            table.insert(foundRemotes, descendant.Name)
        end
    end
    
    if #foundRemotes > 0 then
        print("[Discovery] Found remotes in ReplicatedStorage: " .. table.concat(foundRemotes, ", "))
    else
        print("[Discovery] No remotes found in ReplicatedStorage")
    end
    
    -- Search for matching pattern
    for _, pattern in ipairs(remotePatterns) do
        for _, descendant in ipairs(descendants) do
            local isRemote = descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")
            if isRemote then
                local success, matches = pcall(function()
                    -- Exact match or contains pattern
                    return descendant.Name == pattern or 
                           string.find(descendant.Name, pattern, 1, true) ~= nil
                end)
                
                if success and matches then
                    print("[Discovery] Found collect remote: " .. descendant.Name .. " (" .. descendant.ClassName .. ")")
                    return descendant
                end
            end
        end
    end
    
    warn("[Discovery] Could not find collect remote using any known pattern")
    return nil
end

-- ============================================================================
-- discoverGameStructure()
-- Aggregates all discovery results into a single object
-- Returns: table with discovery results
-- ============================================================================
local function discoverGameStructure()
    print("[Discovery] === Starting Game Structure Discovery ===")
    
    local playerFolder = findPlayerFolder()
    local collectRemote = findCollectRemote()
    local animals = findPlayerAnimals()
    
    local result = {
        playerFolder = playerFolder,
        collectRemote = collectRemote,
        animalCount = #animals,
        animals = animals
    }
    
    -- Print summary
    print("[Discovery] === Discovery Summary ===")
    print("[Discovery] Player folder: " .. (playerFolder and playerFolder:GetFullName() or "NOT FOUND"))
    print("[Discovery] Collect remote: " .. (collectRemote and collectRemote.Name or "NOT FOUND"))
    print("[Discovery] Animal count: " .. result.animalCount)
    
    -- Check money ready status for each animal
    local readyCount = 0
    for _, animal in ipairs(animals) do
        local ready, amount = isMoneyReady(animal)
        if ready then
            readyCount = readyCount + 1
        end
    end
    print("[Discovery] Animals with money ready: " .. readyCount)
    result.readyCount = readyCount
    
    print("[Discovery] === Discovery Complete ===")
    
    return result
end

Discovery.findPlayerFolder = findPlayerFolder
Discovery.findPlayerAnimals = findPlayerAnimals
Discovery.isMoneyReady = isMoneyReady
Discovery.findCollectRemote = findCollectRemote
Discovery.discoverGameStructure = discoverGameStructure

return Discovery
