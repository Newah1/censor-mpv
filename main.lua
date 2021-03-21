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

function seek(time)
    mp.command('seek '.. time .. ' absolute exact')
end

function every_millisecond()
    local current_timestamp = get_current_timestamp()    

    if current_timestamp > (state["begin"]) and current_timestamp < (state['end']) then
        seek(state['end'])
        code_seek_just_performed = true
        print('Seeked, now moving to the next...')
        next_state()
    end
    
end

function set_filter(filter, index)
    state['index'] = index
    state['begin'] = tonumber(filter['begin']) + offset
    state['end'] = tonumber(filter['end']) + offset
    state['description'] = filter['description']
    print('Set filter to index ' .. index .. ' ' .. state['description'])
end

function reset_find_filters()
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

        if current_timestamp >= begin and current_timestamp < e then
            print('Currently IN a filter.')
            seek(e)
            code_seek_just_performed = true
        end


        if current_timestamp <= begin then
            set_filter(value, i)
            return
        end

        last_filter = value
        i = i + 1
    end

    print('No more filters after seek.')
end

function handler()
    print('File loaded... checking for filters!')
    state['index'] = 1
    if checker.stop ~= nil then
        checker.stop()
    end
    local file_path = mp.get_property('path', nil)
    local filters = get_filters_json(file_path)


    all_filters = filters

    next_state()
    checker = mp.add_periodic_timer(0.05, every_millisecond)
    print(state['begin'])

end

function done()
    print('done')
    checker.stop()
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

mp.register_event('seek', seek_event)

print('test')