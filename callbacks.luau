local callbacks = {
    setup = {},
    connections = {},
    input_connect = nil,
    unhook_button = Enum.KeyCode.F1,
    unhook_text = nil,
    inited = false,
    services = {},
    log = print,
    autoinit = true,
}; do
    callbacks.services = {
        RunService = game:GetService("RunService"),
        UserInputService = game:GetService("UserInputService"),
        unload = {},
    }

    local function safe_wrap(fn)
        return function(...)
            local function err(e)
                return debug.traceback(e, 2)
            end

            local ok, msg = xpcall(fn, err, ...)
            if not ok then
                warn(msg)
            end
        end
    end

    ---@param serviceName string
    ---@param eventName string
    ---@param fn function
    function callbacks.add(serviceName, eventName, fn)
        fn = safe_wrap(fn)

        local service = callbacks.services[serviceName]
        if not service then
            local success, srv = pcall(game.GetService, game, serviceName)
            if not success then
                error("Service not found: " .. tostring(serviceName))
                return
            end
            service = srv
            callbacks.services[serviceName] = service
        end

        if not callbacks.setup[eventName] then
            callbacks.setup[eventName] = {}
        end
        table.insert(callbacks.setup[eventName], {service = service, fn = fn})

        if callbacks.inited and service[eventName] then
            table.insert(callbacks.connections, service[eventName]:Connect(fn))
        end
    end

    ---@param fn function
    function callbacks.unload(fn)
        if type(fn) == "string" then
            callbacks.unhook_text = fn
            return
        end

        fn = safe_wrap(fn)

        table.insert(callbacks.services.unload, fn)
    end

    function callbacks.init(text)
        if callbacks.inited then
            return
        end

        for eventName, entries in pairs(callbacks.setup) do
            for _, entry in ipairs(entries) do
                local service, fn = entry.service, entry.fn
                if service[eventName] then
                    table.insert(callbacks.connections, service[eventName]:Connect(fn))
                end
            end
        end

        local UIS = callbacks.services.UserInputService
        callbacks.input_connect = UIS.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == callbacks.unhook_button then
                callbacks.clear()
            end
        end)

        callbacks.inited = true
        callbacks.log(text or "Hooks set successfully")
    end

    function callbacks.clear(text)
        text = text or callbacks.unhook_text

        for _, conn in ipairs(callbacks.connections) do
            conn:Disconnect()
        end

        callbacks.connections = {}
        if callbacks.input_connect then
            callbacks.input_connect:Disconnect()
            callbacks.input_connect = nil
        end

        for _, fn in ipairs(callbacks.services.unload) do
            fn()
        end

        callbacks.inited = false
        callbacks.log(text or "Hooks removed successfully")
    end

    if callbacks.autoinit then
        callbacks.init()
    end
end
