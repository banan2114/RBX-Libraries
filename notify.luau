local notify = {}; do

local Config = {
    Font = Enum.Font.Code,
    TextSize = 14,
    TextColor = Color3.fromRGB(255, 255, 255),
    BackgroundColor = Color3.fromRGB(30, 30, 30),
    BackgroundTransparency = 0.1,
    Padding = 6,
    Spacing = 4,
    DefaultDuration = 3,
    MaxNotifications = 10,
    Position = UDim2.new(0, 10, 0, 10),
    FadeTime = 0.3,
}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local orderCounter = 0
local notifications = {}

local screenGui = Instance.new("ScreenGui"); do
    screenGui.Name = "SimpleNotify"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 999999999

    pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)

    if not screenGui.Parent then
        screenGui.Parent = playerGui
    end
end

local container = Instance.new("Frame"); do
    container.Name = "Container"
    container.BackgroundTransparency = 1
    container.Position = Config.Position
    container.Size = UDim2.new(0, 400, 1, -20)
    container.Parent = screenGui
end

local listLayout = Instance.new("UIListLayout"); do
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, Config.Spacing)
    listLayout.Parent = container
end

local function createNotification(text, duration)
    if not (text and text ~= "") then
        return
    end

    duration = duration or Config.DefaultDuration

    while #notifications >= Config.MaxNotifications do
        local oldest = table.remove(notifications, 1)
        if oldest and oldest.Parent then
            oldest:Destroy()
        end
    end

    orderCounter = orderCounter + 1

    local label = Instance.new("TextLabel"); do
        label.Name = "Notification"
        label.LayoutOrder = orderCounter
        label.AutomaticSize = Enum.AutomaticSize.XY
        label.BackgroundColor3 = Config.BackgroundColor
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.Font = Config.Font
        label.Text = text
        label.TextSize = Config.TextSize
        label.TextColor3 = Config.TextColor
        label.TextTransparency = 1
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.RichText = true
    end

    local padding = Instance.new("UIPadding"); do
        padding.PaddingTop = UDim.new(0, Config.Padding)
        padding.PaddingBottom = UDim.new(0, Config.Padding)
        padding.PaddingLeft = UDim.new(0, Config.Padding)
        padding.PaddingRight = UDim.new(0, Config.Padding)
        padding.Parent = label
    end

    local corner = Instance.new("UICorner"); do
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = label
    end

    label.Parent = container
    table.insert(notifications, label)

    local fadeIn = TweenService:Create(label, TweenInfo.new(Config.FadeTime), {
        TextTransparency = 0,
        BackgroundTransparency = Config.BackgroundTransparency
    })

    fadeIn:Play()

    task.delay(duration, function()
        if not label.Parent then
            return
        end

        local fadeOut = TweenService:Create(label, TweenInfo.new(Config.FadeTime), {
            TextTransparency = 1,
            BackgroundTransparency = 1
        })

        fadeOut:Play()
        fadeOut.Completed:Wait()

        local index = table.find(notifications, label)
        if index then
            table.remove(notifications, index)
        end

        label:Destroy()
    end)

    return label
end

function notify:Clear()
    for _, notif in ipairs(notifications) do
        if notif and notif.Parent then
            notif:Destroy()
        end
    end

    notifications = {}
end

function notify:Destroy()
    self:Clear()
    screenGui:Destroy()
end

setmetatable(notify, {
    __call = function(_, text, duration)
        return createNotification(tostring(text), duration)
    end
})
end
