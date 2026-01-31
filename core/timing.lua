-- core/timing.lua
-- Randomized timing utilities for anti-detection

local Timing = {}

-- Gaussian random using Box-Muller transform
-- Returns normally distributed random number with given mean and standard deviation
function Timing.gaussianRandom(mean, stdDev)
    local u1 = math.random()
    local u2 = math.random()
    -- Avoid log(0) which is undefined
    if u1 < 0.0001 then u1 = 0.0001 end
    local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
    return z0 * stdDev + mean
end

-- Get delay with variance (10-30% as specified in FARM-05)
-- baseDelay: the target delay in seconds
-- variancePercent: 0.1 to 0.3 (10% to 30%), defaults to 0.2 (20%)
function Timing.getDelay(baseDelay, variancePercent)
    variancePercent = variancePercent or 0.2 -- Default 20%
    -- stdDev calculated so ~95% of values fall within variance range
    local stdDev = baseDelay * variancePercent / 2
    local delay = Timing.gaussianRandom(baseDelay, stdDev)
    -- Clamp to reasonable bounds (never negative, never too long)
    return math.max(0.1, math.min(delay, baseDelay * 2))
end

-- Convenience wrapper that waits with randomized delay
-- Usage: Timing.wait(1) -- waits ~1 second with 20% variance
function Timing.wait(baseDelay, variancePercent)
    local delay = Timing.getDelay(baseDelay, variancePercent)
    task.wait(delay)
    return delay -- Return actual delay for logging if needed
end

-- Random delay within a range (for variety in actions)
-- Usage: Timing.randomWait(0.5, 1.5) -- waits between 0.5 and 1.5 seconds
function Timing.randomWait(minDelay, maxDelay)
    local delay = minDelay + math.random() * (maxDelay - minDelay)
    task.wait(delay)
    return delay
end

return Timing
