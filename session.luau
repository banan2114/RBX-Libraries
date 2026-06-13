local session = {
    log = print,
}; do
    local env = typeof(getgenv) == "function" and getgenv() or nil

    if env and not env.__internal_sessions then
        env.__internal_sessions = {}
    end

    ---Returns true if session was created or resumed, false otherwise
    function session.new(name: string, payload: table?): boolean
        if not env then
            session.log("[session] Environment not supported (getgenv missing)")
            return false
        end

        local registry = env.__internal_sessions
        local data = registry[name]

        if data then
            if data.active then
                session.log("[session] Session '" .. name .. "' already exists and is active")
                return false
            end

            data.active = true
            data.LAT = os.clock()
            if payload then data.payload = payload end

            session.log("[session] Session '" .. name .. "' resumed")
        else
            registry[name] = {
                LAT = os.clock(), -- Last Action Time
                active = true,
                payload = payload or {}
            }

            session.log("[session] New session '" .. name .. "' created")
        end

        return true
    end


    ---Returns session data or nil if session doesn't exist
    function session.get_data(name: string): table?
        if not env or not env.__internal_sessions then return nil end
        local data = env.__internal_sessions[name]
        return data and data.payload
    end

    function session.close(name: string)
        if not env then return end

        local registry = env.__internal_sessions
        local data = registry[name]

        if not data then
            session.log("[session] Session '" .. name .. "' not found")
            return
        end

        if not data.active then
            session.log("[session] Session '" .. name .. "' already closed")
            return
        end

        data.active = false
        data.LAT = os.clock()

        session.log("[session] Session '" .. name .. "' closed")
    end
end