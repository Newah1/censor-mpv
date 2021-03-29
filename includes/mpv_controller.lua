
MPVController = { global_config = {} }


function MPVController:is_muted()
    return (tonumber(mp.get_property('volume')) == 0)
end
function MPVController:get_current_timestamp()
    local current_timestamp = (mp.get_property('time-pos', -1))
    if type(current_timestamp) == "string" then
        current_timestamp = tonumber(current_timestamp)
    end
    return current_timestamp
end

function MPVController:seek(timestamp)
    mp.command('seek '.. timestamp .. ' absolute')
    self.global_config.code_seek_just_performed = true
end

function MPVController:set_volume(volume)
    mp.command('set volume '..volume)
end

function MPVController:toggle_mute()
    local volume = mp.get_property('volume')
    if tonumber(volume) > 0 then
        self.global_config.original_volume = tonumber(volume)
        self:set_volume(0)
    else
        self:set_volume(self.global_config.original_volume)
    end
end

function MPVController:new(o)
    o = o or { global_config = {} }
    setmetatable(o, self)
    self.__index = MPVController
    return o
end

return MPVController