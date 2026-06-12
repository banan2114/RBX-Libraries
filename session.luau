local session = {
    log = print,
}; do
    session.new = function(name)
        if not getgenv then
            session.log("[session] getgenv not found")
            return true
        end

        local env = getgenv()
        local data = env[name]

        if data then
            if data.active then
                session.log("[session] session already exists")
                return false
            end

            data.active = true
            data.LAT = tick()

            session.log("[session] session resumed")
        else
            env[name] = {
                LAT = tick(), -- last action time
                active = true,
            }

            session.log("[session] new session created")
        end

        return true
    end

    session.close = function(name)
        if not getgenv then
            return
        end

        local env = getgenv()
        local data = env[name]

        if not data then
            session.log("[session] session not found")
            return
        end

        local active = data.active
        if not active then
            session.log("[session] session already closed")
            return
        end

        data.active = false
        data.LAT = tick()

        session.log("[session] session closed")
    end
end
