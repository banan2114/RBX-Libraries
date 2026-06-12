local animations = {
    list = {},
    tracks = {},
    current = {},
    global = nil,
}; do
    local players = game:GetService("Players")
    local me = players.LocalPlayer

    animations.hook = function(anim, fn)
        animations.list[anim] = fn
    end

    animations.unhook = function(anim)
        animations.list[anim] = nil
    end

    animations.hook_all = function(fn)
        animations.global = fn
    end

    animations.load = function(anim, animator, priority)
        if animations.tracks[anim] then
            return animations.tracks[anim]
        end

        local track = animator:LoadAnimation(anim)
        if priority then
            track.Priority = priority
        end

        animations.tracks[anim] = track
        return animations.tracks[anim]
    end

    animations.stop = function(list)
        if type(list) ~= "table" then
            list = { list }
        end

        for _, obj in pairs(list) do
            if type(obj) == "table" then
                animations.stop(obj)
            else
                local track = animations.tracks[obj]
                if track then
                    track:Stop()
                end
            end
        end
    end

    animations.play = function(anim, priority)
        table.insert(animations.current, {
            animation = anim,
            priority = priority,
        })
    end

    callbacks.add("RunService", "RenderStepped", function()
        local character = me.Character
        if not character then
            return
        end

        local animator = character.Humanoid.Animator
        if not animator then
            return
        end

        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if animations.global then
                animations.global(track)
            end
            local animation = track.Animation

            if animations.list[animation] then
                animations.list[animation](track)
            end
        end

        for _, request in ipairs(animations.current) do
            local track = animations.load(request.animation, animator, request.priority)

            if not track.IsPlaying then
                track:Play()
            end
        end

        animations.current = {}
    end)
end
