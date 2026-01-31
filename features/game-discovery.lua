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

Discovery.findPlayerFolder = findPlayerFolder
Discovery.findPlayerAnimals = findPlayerAnimals

return Discovery
