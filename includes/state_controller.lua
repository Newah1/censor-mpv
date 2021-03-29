
Filter = require('includes.filter')

StateController = { state = {}, all_filters = {}, global_config = {}, MPVController = {} }


function StateController:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function StateController:set_filter(filter, index)
    self.state = Filter:set(filter, index, self.global_config.offset)
    return self.state
end

function StateController:next_state()
    local current_tag = self.all_filters['results'][1]['tags'][self.state["index"]]
    if current_tag == nil then
        --print('End of the line, bub.')
        return
    end
    
    self:set_filter(current_tag, self.state["index"] + 1)
end

function StateController:reset_find_filters()
    print('Finding current filter')
    local current_timestamp = self.MPVController:get_current_timestamp()

    local last_filter = false

    local i = 1

    for key, value in pairs(self.all_filters['results'][1]['tags']) do
        local begin = value['begin']
        local e = value['end']
        if type(begin) == 'string' then 
            begin = tonumber(begin)
        end
        if type(e) == 'string' then
            e = tonumber(e)
        end

        if current_timestamp >= (begin + self.global_config.offset) and current_timestamp < (e + self.global_config.offset) then
            print('Currently IN a filter.')
            --seek(e)
            self:set_filter(value, i)
            local should_end = self:handle_filter(value)
            if should_end then
                return
            end
            
        end


        if current_timestamp <= (begin + self.global_config.offset) then
            print('Not in a filter, setting to the next filter ahead of playhead. \n CURRENT TIMESTAMP: ' .. current_timestamp .. '\n Start of next filter: ' .. (begin + self.global_config.offset))
            self:set_filter(value, i)
            return
        end

        last_filter = value
        i = i + 1
    end

    print('No more filters after seek.')
end

function StateController:handle_filter(filter)
    local type = filter['type']
    local mute = false
    if type == 'audio' then
        print('Filter is audio.')
        mute = true
    end

    if mute then
        if not self.MPVController:is_muted() then
            print('Muting for audio filter.')
            self.global_config.system_muted = true
            self.MPVController:toggle_mute()
            
        end
        return true
    end

    print('About to seek for audiovisual filter')

    MPVController:seek(filter['end'])
    return false
end

return StateController
