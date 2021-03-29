local config = require("includes.global")
local utils = require("mp.utils")
local json = require("includes.json")
local Filter = require("includes.filter")
local MPVController = require("includes.mpv_controller")
local StateController = require('includes.state_controller')




MPVController = MPVController:new{ global_config = config }

StateController = StateController:new{ state = Filter:new(), all_filters = {}, global_config = config, MPVController = MPVController }

StateController.all_filters = {}

config.checker = {}
config.offset = 0 -- sync the filtering with the source material

config.original_volume = 100
config.system_muted = false

config.code_seek_just_performed = false

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
        config.offset = tonumber(filters['offset'])
    end

    return filters
end

function every_millisecond()

    local current_timestamp = MPVController:get_current_timestamp()    

    if current_timestamp > (StateController.state["begin"]) and current_timestamp < (StateController.state['end']) then
        --seek(state['end'])
        StateController:handle_filter(StateController.state)
        
    elseif current_timestamp > (StateController.state['end']) then
        --print('Reached the end of filter; moving to the next...')
        if config.system_muted then
            MPVController:toggle_mute()
            config.system_muted = false
        end
        StateController:next_state()
    end
    
end


function reset()
    print('Running a reset...')
    StateController.state['index'] = 1
    if config.checker.stop ~= nil then
        config.checker.stop()
    end
    local volume = mp.get_property('volume')
    print(volume)
    config.original_volume = tonumber(volume)
end

function handler()
    print('File loaded... checking for filters!')
    
    
    reset()

    local file_path = mp.get_property('path', nil)
    local filters = get_filters_json(file_path)


    StateController.all_filters = filters

    StateController:next_state()
    config.checker = mp.add_periodic_timer(0.05, every_millisecond)
    print(StateController.state['begin'])

end

function done()
    print('done')
    if config.checker.kill ~= nil then
        config.checker:kill()
    end
end

function seek_event() 
    print('Seek event detected.')
    if config.code_seek_just_performed then
        print('It was a code seek event. Returning.')
        config.code_seek_just_performed = false
        return
    end

    StateController:reset_find_filters()

end


mp.register_event('file-loaded', handler)
mp.register_event('end-file', done)

mp.register_event('playback-restart', seek_event)