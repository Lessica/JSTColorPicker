local generator = function (image, ...)
    local args = {...}
    local str = "{\n"
    for _, a in ipairs(args) do
        if a.color ~= nil then
            str = str .. "  { " .. string.format("%4d", a.x) .. ", " .. string.format("%4d", a.y) .. ", " .. string.format("0x%06x", a.color & 0xffffff) .. " },  -- " .. tostring(a.id) .. "\n"
        end
    end
    str = str .. "}"
    return str
end

return {
    uuid = "4F097F53-0FC3-494E-8F63-755A13775E9F",
    name = "\xe2\x80\x8bXXTouch 普通表结构",
    version = "1.0",
    platformVersion = "2.2",
    author = "xtzn",
    extension = "lua",
    enabled = true,
    previewable = true,
    generator = generator,
}
