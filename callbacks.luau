local callbacks = {
    setup = {},
    connections = {},
    unload_tasks = {},
    input_connect = nil,
    unhook_button = Enum.KeyCode.F1,
    unhook_text = "Hooks removed successfully",
    inited = false,
    services = {
        RunService = game:GetService("RunService"),
        UserInputService = game:GetService("UserInputService"),
    },
    log = print,
}; do
    local function err_handler(e)
        return debug.traceback(tostring(e), 2)
    end

    local function safe_wrap(fn)
        return function(...)
            local ok, msg = xpcall(fn, err_handler, ...)
            if not ok then
                warn(msg)
            end
        end
    end

    ---@param serviceName string
    ---@param eventName string
    ---@param fn function
    ---@return RBXScriptConnection|nil
    function callbacks.add(serviceName, eventName, fn)
        local wrapped_fn = safe_wrap(fn)

        local service = callbacks.services[serviceName]
        if not service then
            local success, srv = pcall(function() return game:GetService(serviceName) end)
            if not success then
                warn("Service not found: " .. tostring(serviceName))
                return nil
            end
            service = srv
            callbacks.services[serviceName] = service
        end

        if not callbacks.setup[eventName] then
            callbacks.setup[eventName] = {}
        end
        table.insert(callbacks.setup[eventName], {service = service, fn = wrapped_fn})

        if callbacks.inited and service[eventName] then
            local connection = service[eventName]:Connect(wrapped_fn)
            table.insert(callbacks.connections, connection)
            return connection
        end

        return nil
    end

    ---@param fn function
    function callbacks.unload(fn)
        table.insert(callbacks.unload_tasks, safe_wrap(fn))
    end

    function callbacks.init(text)
        if callbacks.inited then return end

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
            if conn.Connected then
                conn:Disconnect()
            end
        end
        callbacks.connections = {}

        if callbacks.input_connect then
            callbacks.input_connect:Disconnect()
            callbacks.input_connect = nil
        end

        for _, fn in ipairs(callbacks.unload_tasks) do
            fn()
        end
        callbacks.unload_tasks = {}

        callbacks.inited = false
        callbacks.log(text)
    end
end