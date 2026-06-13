local animations = {
    list = {},
    tracks = {},
    current = {},
    global = nil,
    processed_tracks = {},
}; do
    setmetatable(animations.list, { __mode = "k" })
    setmetatable(animations.tracks, { __mode = "k" })
    setmetatable(animations.processed_tracks, { __mode = "k" })

    local players = game:GetService("Players")
    local me = players.LocalPlayer

    me.CharacterAdded:Connect(function()
        table.clear(animations.tracks)
        table.clear(animations.processed_tracks)
    end)

    function animations.hook(anim, fn)
        animations.list[anim] = fn
    end

    function animations.unhook(anim)
        animations.list[anim] = nil
    end

    function animations.load(anim, animator, priority)
        if animations.tracks[anim] then return animations.tracks[anim] end
        local success, track = pcall(function() return animator:LoadAnimation(anim) end)
        if not success or not track then return nil end
        if priority then track.Priority = priority end
        animations.tracks[anim] = track
        return track
    end

    function animations.play(anim, priority)
        table.insert(animations.current, { animation = anim, priority = priority })
    end

    local function get_animator()
        local character = me.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        return humanoid and humanoid:FindFirstChildOfClass("Animator")
    end

    callbacks.add("RunService", "RenderStepped", function()
        local animator = get_animator()
        if not animator then return end

        local playing_tracks = animator:GetPlayingAnimationTracks()
        local current_frame_tracks = {}

        for _, track in ipairs(playing_tracks) do
            local animation = track.Animation
            current_frame_tracks[track] = true

            local is_first_frame = not animations.processed_tracks[track]
            if is_first_frame then
                animations.processed_tracks[track] = { stopped = false }
            end

            if animations.processed_tracks[track].stopped then
                continue
            end

            local function safe_stop()
                if not animations.processed_tracks[track].stopped then
                    animations.processed_tracks[track].stopped = true
                    track:Stop()
                end
            end

            if animations.global then
                animations.global(track, is_first_frame, safe_stop)
            end

            local hook_fn = animations.list[animation]
            if hook_fn then
                hook_fn(track, is_first_frame, safe_stop)
            end
        end

        for track in pairs(animations.processed_tracks) do
            if not current_frame_tracks[track] then
                animations.processed_tracks[track] = nil
            end
        end

        if #animations.current > 0 then
            for _, request in ipairs(animations.current) do
                local track = animations.load(request.animation, animator, request.priority)
                if track and not track.IsPlaying then
                    track:Play()
                end
            end
            table.clear(animations.current)
        end
    end)
end