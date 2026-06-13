local keyboard = {}; do
    local vim = game:GetService("VirtualInputManager")

    keyboard.press = function(keyCode, holdTime)
        vim:SendKeyEvent(true, keyCode, false, game)
        task.wait(holdTime or 0.03)
        vim:SendKeyEvent(false, keyCode, false, game)
    end

    keyboard.release = function(keyCode)
        vim:SendKeyEvent(false, keyCode, false, game)
    end

    keyboard.hold = function(keyCode, duration)
        vim:SendKeyEvent(true, keyCode, false, game)
        task.wait(duration or 0.5)
        vim:SendKeyEvent(false, keyCode, false, game)
    end

    keyboard.combo = function(delayBetweenKeys, ...)
        local keys = {...}
        for i = 1, #keys do
            keyboard.press(keys[i])

            if i < #keys then
                task.wait(delayBetweenKeys or 0.05)
            end
        end
    end
end

local mouse = {}; do
    local vim = game:GetService("VirtualInputManager")
    local uis = game:GetService("UserInputService")
    local guiService = game:GetService("GuiService")

    mouse.position = function()
        local rawPos = uis:GetMouseLocation()
        local inset = guiService:GetGuiInset()
        return Vector2.new(rawPos.X, rawPos.Y - inset.Y)
    end

    mouse.click = function(x, y, button)
        button = button or 0 -- 0 = left, 1 = right, 2 = middle
        local currentPos = mouse.position()
        x = x or currentPos.X
        y = y or currentPos.Y

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

        local hz = 60
        local steps = math.ceil(duration * hz)
        local frameTime = 1 / hz

        vim:SendMouseButtonEvent(fromX, fromY, button, true, game, 1)
        task.wait(frameTime)

        for i = 1, steps do
            local t = i / steps
            local smoothT = t * t * (3 - 2 * t)

            local x = fromX + (toX - fromX) * smoothT
            local y = fromY + (toY - fromY) * smoothT

            vim:SendMouseMoveEvent(x, y, game)
            task.wait(frameTime)
        end

        vim:SendMouseButtonEvent(toX, toY, button, false, game, 1)
    end

    mouse.worldToScreen = function(worldPos)
        local camera = workspace.CurrentCamera
        if not camera then return Vector2.new(0, 0), false end

        local screenPos, onScreen = camera:WorldToScreenPoint(worldPos)
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