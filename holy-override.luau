--!strict
--!optimize 2

export type OverrideEntry = {
    instance: Instance,
    properties: { [string]: any }?,
    attributes: { [string]: any }?,
    activeProps: { [string]: any },  
    activeAttrs: { [string]: any },
    defaultProps: { [string]: any }, 
    defaultAttrs: { [string]: any },
    delete: boolean,
    connections: { RBXScriptConnection },
    active: boolean,
    isWritingProp: { [string]: boolean },
    isWritingAttr: { [string]: boolean },
}

local override = {
    list = {} :: { [string]: OverrideEntry },
    None = newproxy(false) :: any,
}

do
    local instanceMap = setmetatable({}, { __mode = "k" }) :: { [Instance]: string }

    local function deepCloneAndFreeze(t: any): { [string]: any }?
        if type(t) ~= "table" then return nil end
        
        local copy = {}
        local visited = {}
        
        local current = t
        while current and type(current) == "table" and not visited[current] do
            visited[current] = true
            for k, v in pairs(current) do 
                if copy[k] == nil then copy[k] = v end 
            end
            
            local meta = getmetatable(current)
            if meta and type(meta.__index) == "table" then
                current = meta.__index
            else
                break
            end
        end
        
        table.freeze(copy)
        return copy
    end

    local function isEqual(a: any, b: any): boolean
        if a == b then return true end
        if type(a) == "number" and type(b) == "number" and a ~= a and b ~= b then return true end
        return false
    end

    local function resolveValue(value: any): any
        if value == override.None then return nil end
        return value
    end

    local function safeWrite(action: () -> ())
        if setfenv and not getfenv then return end -- Bypass if environment acts weird
        pcall(function()
            if task and task.cancel then
            end
        end)
        action()
    end

    local function applyPropOverride(entry: OverrideEntry, key: string, value: any)
        local realValue = resolveValue(value)
        
        local currentSuccess, currentEngineVal = pcall(function() return (entry.instance :: any)[key] end)
        if currentSuccess and isEqual(currentEngineVal, realValue) then
            entry.activeProps[key] = currentEngineVal
            return 
        end

        entry.isWritingProp[key] = true
        
        safeWrite(function()
            local success, actualVal = pcall(function()
                (entry.instance :: any)[key] = realValue
                return (entry.instance :: any)[key] 
            end)
            if success then entry.activeProps[key] = actualVal end
        end)

        entry.isWritingProp[key] = false
    end

    local function applyAttrOverride(entry: OverrideEntry, key: string, value: any)
        local realValue = resolveValue(value)
        
        local currentEngineVal = entry.instance:GetAttribute(key)
        if isEqual(currentEngineVal, realValue) then
            entry.activeAttrs[key] = currentEngineVal
            return
        end

        entry.isWritingAttr[key] = true
        
        safeWrite(function()
            local success, actualVal = pcall(function()
                entry.instance:SetAttribute(key, realValue)
                return entry.instance:GetAttribute(key)
            end)
            if success then entry.activeAttrs[key] = actualVal end
        end)

        entry.isWritingAttr[key] = false
    end

    local function killConnections(entry: OverrideEntry)
        if entry.connections then
            for _, conn in pairs(entry.connections) do
                conn:Disconnect()
            end
            table.clear(entry.connections)
        end
    end

    local function restoreOrDelete(entry: OverrideEntry, index: string)
        killConnections(entry) 
        instanceMap[entry.instance] = nil

        if not entry.instance then return end

        if entry.delete then
            pcall(function() entry.instance:Destroy() end)
        else
            if entry.properties then
                for key, _ in pairs(entry.properties) do
                    entry.isWritingProp[key] = true
                    local defVal = resolveValue(entry.defaultProps[key])
                    safeWrite(function() pcall(function() (entry.instance :: any)[key] = defVal end) end)
                    entry.isWritingProp[key] = false
                end
            end

            if entry.attributes then
                for key, _ in pairs(entry.attributes) do
                    entry.isWritingAttr[key] = true
                    local defVal = resolveValue(entry.defaultAttrs[key])
                    safeWrite(function() pcall(function() entry.instance:SetAttribute(key, defVal) end) end)
                    entry.isWritingAttr[key] = false
                end
            end
        end
    end

    local function bindDestruction(index: string, entry: OverrideEntry)
        table.insert(entry.connections, entry.instance.Destroying:Connect(function()
            killConnections(entry) 
            instanceMap[entry.instance] = nil
            override.list[index] = nil
        end))
    end

    function override.fromInstance(
        index: string, 
        instance: any, 
        properties: any, 
        attributes: any
    ): boolean
        if typeof(instance) ~= "Instance" then return false end
        if type(index) ~= "string" then return false end
        if override.list[index] then return false end
        
        if instanceMap[instance] then
            warn(string.format("[Override] Instance '%s' is already hooked at index '%s'!", instance.Name, instanceMap[instance]))
            return false
        end

        local safeProps = deepCloneAndFreeze(properties)
        local safeAttrs = deepCloneAndFreeze(attributes)

        local entry: OverrideEntry = {
            instance = instance,
            properties = safeProps,
            attributes = safeAttrs,
            activeProps = {},
            activeAttrs = {},
            defaultProps = {},
            defaultAttrs = {},
            delete = false,
            connections = {},
            active = false,
            isWritingProp = {},
            isWritingAttr = {},
        }
        
        override.list[index] = entry
        instanceMap[instance] = index
        bindDestruction(index, entry)

        if safeProps then
            for key, _ in pairs(safeProps) do
                local readSuccess, initialVal = pcall(function() return (instance :: any)[key] end)
                if not readSuccess then continue end 
                
                entry.defaultProps[key] = (initialVal == nil) and override.None or initialVal
                entry.isWritingProp[key] = false
                
                local connSuccess, connection = pcall(function()
                    return instance:GetPropertyChangedSignal(key):Connect(function()
                        if entry.isWritingProp[key] then return end 
                        
                        local rSuccess, currentVal = pcall(function() return (instance :: any)[key] end)
                        if not rSuccess then return end
                        
                        if entry.active and entry.properties then
                            if isEqual(currentVal, entry.activeProps[key]) then return end
                            
                            entry.defaultProps[key] = (currentVal == nil) and override.None or currentVal
                            applyPropOverride(entry, key, entry.properties[key])
                        else
                            entry.defaultProps[key] = (currentVal == nil) and override.None or currentVal
                        end
                    end)
                end)
                
                if connSuccess and connection then
                    table.insert(entry.connections, connection)
                end
            end
        end

        if safeAttrs then
            for key, _ in pairs(safeAttrs) do
                local initialVal = instance:GetAttribute(key)
                entry.defaultAttrs[key] = (initialVal == nil) and override.None or initialVal
                entry.isWritingAttr[key] = false

                local connSuccess, connection = pcall(function()
                    return instance:GetAttributeChangedSignal(key):Connect(function()
                        if entry.isWritingAttr[key] then return end

                        local currentVal = instance:GetAttribute(key)
                        
                        if entry.active and entry.attributes then
                            if isEqual(currentVal, entry.activeAttrs[key]) then return end
                            
                            entry.defaultAttrs[key] = (currentVal == nil) and override.None or currentVal
                            applyAttrOverride(entry, key, entry.attributes[key])
                        else
                            entry.defaultAttrs[key] = (currentVal == nil) and override.None or currentVal
                        end
                    end)
                end)
                
                if connSuccess and connection then
                    table.insert(entry.connections, connection)
                end
            end
        end

        return true
    end

    function override.fromClass(
        index: string, 
        parent: any, 
        className: any, 
        properties: any, 
        attributes: any
    ): boolean
        if typeof(parent) ~= "Instance" then return false end
        if type(className) ~= "string" then return false end
        if type(index) ~= "string" then return false end
        if override.list[index] then return false end

        local instance = parent:FindFirstChildOfClass(className)
        local delete = false
        local needsParenting = false

        if not instance then
            delete = true
            local success, newInstance = pcall(function() return Instance.new(className) end)
            if not success or not newInstance then return false end
            
            instance = newInstance
            instance.Name = className
            needsParenting = true 
        end
        
        if instanceMap[instance :: Instance] then
            if needsParenting then pcall(function() instance:Destroy() end) end 
            warn(string.format("[Override] Instance of class '%s' is already hooked!", className))
            return false
        end

        local safeProps = deepCloneAndFreeze(properties)
        local safeAttrs = deepCloneAndFreeze(attributes)

        local entry: OverrideEntry = {
            instance = instance :: Instance,
            properties = safeProps,
            attributes = safeAttrs,
            activeProps = {},
            activeAttrs = {},
            defaultProps = {},
            defaultAttrs = {},
            delete = delete,
            connections = {},
            active = false,
            isWritingProp = {},
            isWritingAttr = {},
        }
        
        override.list[index] = entry
        instanceMap[instance :: Instance] = index
        bindDestruction(index, entry)

        if safeProps then
            for key, _ in pairs(safeProps) do
                local readSuccess, initialVal = pcall(function() return (instance :: any)[key] end)
                if not readSuccess then continue end 
                
                entry.defaultProps[key] = (initialVal == nil) and override.None or initialVal
                entry.isWritingProp[key] = false

                local connSuccess, connection = pcall(function()
                    return (instance :: Instance):GetPropertyChangedSignal(key):Connect(function()
                        if entry.isWritingProp[key] then return end
                        
                        local rSuccess, currentVal = pcall(function() return (instance :: any)[key] end)
                        if not rSuccess then return end
                        
                        if entry.active and entry.properties then
                            if isEqual(currentVal, entry.activeProps[key]) then return end
                            
                            entry.defaultProps[key] = (currentVal == nil) and override.None or currentVal
                            applyPropOverride(entry, key, entry.properties[key])
                        else
                            entry.defaultProps[key] = (currentVal == nil) and override.None or currentVal
                        end
                    end)
                end)
                
                if connSuccess and connection then
                    table.insert(entry.connections, connection)
                end
            end
        end
        
        if safeAttrs then
            for key, _ in pairs(safeAttrs) do
                local initialVal = (instance :: Instance):GetAttribute(key)
                entry.defaultAttrs[key] = (initialVal == nil) and override.None or initialVal
                entry.isWritingAttr[key] = false

                local connSuccess, connection = pcall(function()
                    return (instance :: Instance):GetAttributeChangedSignal(key):Connect(function()
                        if entry.isWritingAttr[key] then return end
                        
                        local currentVal = (instance :: Instance):GetAttribute(key)
                        
                        if entry.active and entry.attributes then
                            if isEqual(currentVal, entry.activeAttrs[key]) then return end
                            
                            entry.defaultAttrs[key] = (currentVal == nil) and override.None or currentVal
                            applyAttrOverride(entry, key, entry.attributes[key])
                        else
                            entry.defaultAttrs[key] = (currentVal == nil) and override.None or currentVal
                        end
                    end)
                end)
                
                if connSuccess and connection then
                    table.insert(entry.connections, connection)
                end
            end
        end

        if needsParenting then
            safeWrite(function() pcall(function() (instance :: Instance).Parent = parent end) end)
        end

        return true
    end

    function override.set(indices: any)
        if not indices then return end 

        if type(indices) == "string" then
            indices = { indices }
        end
        
        if type(indices) ~= "table" then return end

        for _, index in pairs(indices) do
            if type(index) ~= "string" then continue end
            local entry = override.list[index]
            if not entry or not entry.instance then continue end

            entry.active = true

            if entry.properties then
                for key, value in pairs(entry.properties) do
                    applyPropOverride(entry, key, value)
                end
            end

            if entry.attributes then
                for key, value in pairs(entry.attributes) do
                    applyAttrOverride(entry, key, value)
                end
            end
        end
    end

    function override.clear(indices: any)
        if not indices then return end
        
        if type(indices) == "string" then
            indices = { indices }
        end
        
        if type(indices) ~= "table" then return end

        for _, index in pairs(indices) do
            if type(index) ~= "string" then continue end
            local entry = override.list[index]
            if entry then
                entry.active = false
                restoreOrDelete(entry, index)
                override.list[index] = nil
            end
        end
    end

    function override.clearAll()
        for index, entry in pairs(override.list) do
            entry.active = false
            restoreOrDelete(entry, index)
            override.list[index] = nil
        end
    end
end

return override