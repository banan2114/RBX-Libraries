local keyboard = {}; do
    local VirtualInputManager = game:GetService("VirtualInputManager")

    keyboard.press = function(keyCode)
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end

    keyboard.release = function(keyCode)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end

    keyboard.hold = function(keyCode, duration)
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(duration or 0.5)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end

    keyboard.combo = function(delay, ...)
        local args = {...}
        for _, keyCode in ipairs(args) do
            keyboard.hold(keyCode, delay)
        end
    end
end

local mouse = {}; do
    local vim = game:GetService("VirtualInputManager")
    local uis = game:GetService("UserInputService")
    local camera = workspace.CurrentCamera

    mouse.position = function()
        return uis:GetMouseLocation()
    end

    mouse.click = function(x, y, button)
        button = button or 0 -- 0 = left, 1 = right, 2 = middle
        x = x or mouse.position().X
        y = y or mouse.position().Y

        vim:SendMouseButtonEvent(x, y, button, true, game, 1)
        task.wait(0.01)
        vim:SendMouseButtonEvent(x, y, button, false, game, 1)
    end

    mouse.move = function(x, y)
        vim:SendMouseMoveEvent(x, y, game)
    end

    mouse.scroll = function(direction)
        local pos = mouse.position()
        vim:SendMouseWheelEvent(pos.X, pos.Y, direction > 0, game)
    end

    mouse.drag = function(fromX, fromY, toX, toY, duration, button)
        button = button or 0
        duration = duration or 0.5
        local steps = math.ceil(duration / 0.016)

        vim:SendMouseButtonEvent(fromX, fromY, button, true, game, 1)

        for i = 1, steps do
            local t = i / steps
            local x = fromX + (toX - fromX) * t
            local y = fromY + (toY - fromY) * t
            vim:SendMouseMoveEvent(x, y, game)
            task.wait(0.016)
        end

        vim:SendMouseButtonEvent(toX, toY, button, false, game, 1)
    end

    mouse.worldToScreen = function(worldPos)
        local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
        return Vector2.new(screenPos.X, screenPos.Y), onScreen
    end

    mouse.clickWorld = function(worldPos, button)
        local screenPos, onScreen = mouse.worldToScreen(worldPos)
        if onScreen then
            mouse.click(screenPos.X, screenPos.Y, button)
        end
        return onScreen
    end
end
