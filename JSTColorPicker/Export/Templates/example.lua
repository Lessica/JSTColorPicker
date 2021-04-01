local generator = function (image, ...)
    --[=[
    --    `image` is a lua table which represents the opened image document in current window:
    --        `image.path`
    --        `image.filename`
    --        `image.width`: image width in pixels
    --        `image.height`: image height in pixels
    --        `image.get_color(x, y)`: returns **argb** 32-bit integer value of color
    --        `image.get_image(x, y, w, h)`: returns png data representation
    ]=]
    local args = {...}
    --[=[
    --    `args` is a lua sequence of *colors* and *areas*:
    --    *color* item:
    --        `color.id`
    --        `color.name`
    --        `color.tags`
    --        `color.similarity`
    --        `color.x`
    --        `color.y`
    --        `color.color`: **argb** 32-bit integer value of color
    --    *area* item:
    --        `area.id`
    --        `area.name`
    --        `area.tags`
    --        `area.similarity`
    --        `area.minX`
    --        `area.minY`
    --        `area.maxX`
    --        `area.maxY`
    --        `area.width`: area width in pixels
    --        `area.height`: area height in pixels
    --    Test the existence of `item.width` to check if the item is a *color* or an *area*.
    ]=]
    local function dump(o)
        if type(o) == 'table' then
            local s = '{ '
            for k,v in pairs(o) do
                if type(k) ~= 'number' then k = '"'..k..'"' end
                s = s .. '['..tostring(k)..'] = ' .. dump(v) .. ','
            end
            return s .. '} '
        else
            return tostring(o)
        end
    end
    --
    local function chunk(text, size)
        local s = {}
        for i = 1, #text, size do
            s[#s + 1] = text:sub(i, i + size - 1)
        end
        return s
    end
    if #args == 1 then
        local processed = false
        local str = "x, y = screen.find_image("
        local extraEndings = ""
        str = str .. "[[\n"
        for _, a in ipairs(args) do
            if a.width ~= nil then
                str = str .. table.concat(chunk(image.get_image(a.minX, a.minY, a.width, a.height):gsub(".", function (c)
                    return string.format("\\x%02x", string.byte(c))
                end), 64), "\n")
                extraEndings = ", " .. string.format("%6.2f", a.similarity * 100.0) .. ", " .. tostring(a.minX) .. ", " .. tostring(a.minY) .. ", " .. tostring(a.maxX) .. ", " .. tostring(a.maxY)
                processed = true
            end
            break
        end
        str = str .. "\n]]" .. extraEndings .. ")"
        if processed then
            return str
        end
    end
    --
    local str = "x, y = screen.find_color("
    local extraEndings = ""
    str = str .. "{\n"
    for _, a in ipairs(args) do
        if a.color ~= nil then
            str = str .. "  { " .. string.format("%4d", a.x) .. ", " .. string.format("%4d", a.y) .. ", " .. string.format("0x%06x", a.color & 0xffffff) .. ", " .. string.format("%6.2f", a.similarity * 100.0) .. " },  -- " .. tostring(a.id) .. "\n"
        elseif #extraEndings == 0 then
            extraEndings = ", " .. string.format("%6.2f", a.similarity * 100.0) .. ", " .. tostring(a.minX) .. ", " .. tostring(a.minY) .. ", " .. tostring(a.maxX) .. ", " .. tostring(a.maxY)
        end
    end
    str = str .. "}" .. extraEndings .. ")"
    return str
end

return {
    uuid = "0C2E7537-45A6-43AD-82A6-35D774414A09",  -- required, a unique UUID4 identifier
    name = "Example",                               -- required, name only for display
    version = "2.2",                                -- required, same template with earlier version will not be displayed
    platformVersion = "2.2",                        -- optional, minimum required software version
    author = "Lessica",                             -- optional, the author of this template script
    description = "This is an example of JSTColorPicker export script.",
    extension = "lua",                              -- required, file extension used for exporting
    generator = generator,                          -- required, the content generator
}
