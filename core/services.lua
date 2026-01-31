-- Build A Zoo Script - Services Module
-- Caches all Roblox services at script start for security and performance
-- IMPORTANT: Must be loaded BEFORE any yields (task.wait, etc.)

local Services = {}

-- Cache immediately on load (before any yields)
-- Using game:GetService() NOT game.ServiceName for security
Services.Players = game:GetService("Players")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.HttpService = game:GetService("HttpService")
Services.RunService = game:GetService("RunService")
Services.TweenService = game:GetService("TweenService")
Services.UserInputService = game:GetService("UserInputService")
Services.Workspace = game:GetService("Workspace")

-- Derived references
Services.LocalPlayer = Services.Players.LocalPlayer

return Services
