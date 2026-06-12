--!strict

export type OverrideEntry = {
    instance: Instance,
    properties: { [string]: any }?,
    attributes: { [string]: any }?,
    defaultProps: { [string]: any },
    defaultAttrs: { [string]: any },
    delete: boolean,
}

local override = {
    list = {} :: { [string]: OverrideEntry },
}; do
    local function restoreOrDelete(entry: OverrideEntry)
        if not (entry.instance and entry.instance.Parent) then return end

        if entry.delete then
            entry.instance:Destroy()
        else
            if entry.properties then
                for key, value in pairs(entry.defaultProps) do
                    (entry.instance :: any)[key] = value
                end
            end

            if entry.attributes then
                for key, value in pairs(entry.defaultAttrs) do
                    entry.instance:SetAttribute(key, value)
                end
            end
        end
    end

    function override.fromInstance(
        index: string, 
        instance: Instance, 
        properties: { [string]: any }?, 
        attributes: { [string]: any }?
    ): boolean
        if override.list[index] then return false end

        local defaultProps = {}
        local defaultAttrs = {}

        if properties then
            for key, _ in pairs(properties) do
                defaultProps[key] = (instance :: any)[key]
            end
        end

        if attributes then
            for key, _ in pairs(attributes) do
                defaultAttrs[key] = instance:GetAttribute(key)
            end
        end

        override.list[index] = {
            instance = instance,
            properties = properties,
            attributes = attributes,
            defaultProps = defaultProps,
            defaultAttrs = defaultAttrs,
            delete = false,
        }

        return true
    end

    function override.fromClass(
        index: string, 
        parent: Instance, 
        className: string, 
        properties: { [string]: any }?, 
        attributes: { [string]: any }?
    ): boolean
        if override.list[index] then return false end

        local instance = parent:FindFirstChildOfClass(className)
        local delete = false

        if not instance then
            delete = true
            instance = Instance.new(className)
            instance.Name = className
            instance.Parent = parent
        end

        local defaultProps = {}
        local defaultAttrs = {}

        if not delete then
            if properties then
                for key, _ in pairs(properties) do
                    defaultProps[key] = (instance :: any)[key]
                end
            end
            if attributes then
                for key, _ in pairs(attributes) do
                    defaultAttrs[key] = instance:GetAttribute(key)
                end
            end
        end

        override.list[index] = {
            instance = instance :: Instance,
            properties = properties,
            attributes = attributes,
            defaultProps = defaultProps,
            defaultAttrs = defaultAttrs,
            delete = delete,
        }

        return true
    end

    function override.set(indices: string | { string })
        if type(indices) == "string" then
            indices = { indices }
        end

        for _, index in pairs(indices :: { string }) do
            local entry = override.list[index]
            if not entry or not entry.instance then continue end

            if entry.properties then
                for key, value in pairs(entry.properties) do
                    (entry.instance :: any)[key] = value
                end
            end

            if entry.attributes then
                for key, value in pairs(entry.attributes) do
                    entry.instance:SetAttribute(key, value)
                end
            end
        end
    end

    function override.clear(indices: string | { string })
        if type(indices) == "string" then
            indices = { indices }
        end

        for _, index in pairs(indices :: { string }) do
            local entry = override.list[index]
            if entry then
                restoreOrDelete(entry)
                override.list[index] = nil
            end
        end
    end

    function override.clearAll()
        for index, entry in pairs(override.list) do
            restoreOrDelete(entry)
            override.list[index] = nil
        end
    end
end
