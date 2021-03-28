local utils = require("mp.utils")
local json = require "json"


local all_filters = {}
local state = {
    ["index"] = 1,
    ["begin"] = 0.0,
    ["end"] = 0.0,
    ["has_next"] = false,
    ["description"] = "No description",
    ["type"] = "audiovisual",
    ["filters"] = {}
}
local checker = {}
local offset = 0 -- sync the filtering with the source material

local original_volume = 100
local system_muted = false

local code_seek_just_performed = false

function load_json(path)
    local json_file = io.open(path, 'r')
    io.input(json_file)
    local filter_json = io.read("*all")
    io.close()
    return filter_json
end

function get_file_extension_name(file_path)
    return string.match(file_path, "([^%.]+)$")
end
function remove_file_extension(file_path, extension)
    return string.gsub(file_path, "."..extension, "")
end
function get_filters_json(filepath)
    local extension = get_file_extension_name(filepath)
    local json_path = remove_file_extension(filepath, extension)
    json_path = json_path .. ".json"

    local filter_json_string = load_json(json_path)
    local filters = json.decode(filter_json_string)

    if filters['offset'] ~= nil then
        print("Setting offset to " .. filters['offset'])
        offset = tonumber(filters['offset'])
    end

    return filters
end

function next_state()
    local current_tag = all_filters['results'][1]['tags'][state["index"]]
    if current_tag == nil then
        print('End of the line, bub.')
        return
    end
    
    set_filter(current_tag, state["index"] + 1)
    
    --state["begin"] = tonumber(current_tag["begin"])
    --state["end"] = tonumber(current_tag["end"])
end

function get_current_timestamp()
    local current_timestamp = (mp.get_property('time-pos', -1))
    if type(current_timestamp) == "string" then
        current_timestamp = tonumber(current_timestamp)
    end
    return current_timestamp
end


function is_muted()
    return (tonumber(mp.get_property('volume')) == 0)
end

function toggle_mute()
    local volume = mp.get_property('volume')
    if tonumber(volume) > 0 then
        original_volume = tonumber(volume)
        mp.command('set volume 0')
    else
        mp.command('set volume ' .. original_volume)
    end
end

function seek(time)
    mp.command('seek '.. time .. ' absolute')
    code_seek_just_performed = true
end

function handle_filter(filter)
    local type = filter['type']
    local mute = false
    if type == 'audio' then
        print('Filter is audio.')
        mute = true
    end

    if mute then
        if not is_muted() then
            print('Muting for audio filter.')
            system_muted = true
            toggle_mute()
            
        end
        return true
    end

    print('About to seek for audiovisual filter')

    seek(filter['end'])
    return false
    
end

function every_millisecond()

    local current_timestamp = get_current_timestamp()    

    if current_timestamp > (state["begin"]) and current_timestamp < (state['end']) then
        --seek(state['end'])
        handle_filter(state)
        
    elseif current_timestamp > (state['end']) then
        print('Reached the end of filter; moving to the next...')
        if system_muted then
            toggle_mute()
            system_muted = false
        end
        next_state()
    end
    
end

function set_filter(filter, index)
    state['index'] = index
    state['begin'] = tonumber(filter['begin']) + offset
    state['end'] = tonumber(filter['end']) + offset
    state['description'] = filter['description']
    state['type'] = filter['type']
    print('Set filter to index ' .. index .. ' ' .. state['description'])
end

function reset_find_filters()
    print('Finding current filter')
    local current_timestamp = get_current_timestamp()

    local last_filter = false

    local i = 1

    for key, value in pairs(all_filters['results'][1]['tags']) do
        local begin = value['begin']
        local e = value['end']
        if type(begin) == 'string' then 
            begin = tonumber(begin)
        end
        if type(e) == 'string' then
            e = tonumber(e)
        end

        if current_timestamp >= (begin + offset) and current_timestamp < (e + offset) then
            print('Currently IN a filter.')
            --seek(e)
            set_filter(value, i)
            local should_end = handle_filter(value)
            if should_end then
                return
            end
            
        end


        if current_timestamp <= (begin + offset) then
            print('Not in a filter, setting to the next filter ahead of playhead. \n CURRENT TIMESTAMP: ' .. current_timestamp .. '\n Start of next filter: ' .. (begin + offset))
            set_filter(value, i)
            return
        end

        last_filter = value
        i = i + 1
    end

    print('No more filters after seek.')
end

function reset()
    print('Running a reset...')
    state['index'] = 1
    if checker.stop ~= nil then
        checker.stop()
    end
    local volume = mp.get_property('volume')
    print(volume)
    original_volume = tonumber(volume)
end

function handler()
    print('File loaded... checking for filters!')
    
    
    reset()

    local file_path = mp.get_property('path', nil)
    local filters = get_filters_json(file_path)


    all_filters = filters

    next_state()
    checker = mp.add_periodic_timer(0.05, every_millisecond)
    print(state['begin'])

end

function done()
    print('done')
    if checker.kill ~= nil then
        checker:kill()
    end
end

function seek_event()
    print('Seek event detected.')
    if code_seek_just_performed then
        print('It was a code seek event. Returning.')
        code_seek_just_performed = false
        return
    end

    reset_find_filters()

end
mp.register_event('file-loaded', handler)
mp.register_event('end-file', done)

mp.register_event('playback-restart', seek_event)

print('test')