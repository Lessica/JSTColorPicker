local generator = function (image, ...)
    --
    local args = {...}
    --
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
    -- print(dump(image))
    -- print(dump(args))
    --
    -- image.get_color(x, y)
    -- image.get_image(x, y, w, h)
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
            if a.w ~= nil then
                str = str .. table.concat(chunk(image.get_image(a.x, a.y, a.w, a.h):gsub(".", function (c)
                    return string.format("\\x%02x", string.byte(c))
                end), 64), "\n")
                extraEndings = ", " .. string.format("%6.2f", a.similarity * 100.0) .. ", " .. tostring(a.x) .. ", " .. tostring(a.y) .. ", " .. tostring(a.x + a.w) .. ", " .. tostring(a.y + a.h)
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
            extraEndings = ", " .. string.format("%6.2f", a.similarity * 100.0) .. ", " .. tostring(a.x) .. ", " .. tostring(a.y) .. ", " .. tostring(a.x + a.w) .. ", " .. tostring(a.y + a.h)
        end
    end
    str = str .. "}" .. extraEndings .. ")"
    return str
end

return {
    uuid = "0C2E7537-45A6-43AD-82A6-35D774414A09",  -- unique, required
    name = "Example",  -- required
    version = "0.1",  -- required
    platformVersion = "1.7",
    author = "Lessica",
    description = "This is an example of JSTColorPicker export script.",
    extension = "lua",
    generator = generator,  -- required
}
