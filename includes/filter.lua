-- based off of the filter object provided by VidAngel in the example.json file

Filter = { index = 1, begin = 0.0, ['end'] = 0.0, has_next = false, description = "", type = "audio" }

function Filter:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Filter:set(filter, index, offset)
    return Filter:new {
        ['index'] = index,
        ['begin'] = tonumber(filter['begin']) + offset,
        ['end'] = tonumber(filter['end']) + offset,
        ['description'] = filter['description'],
        ['type'] = filter['type']
    }
end

return Filter