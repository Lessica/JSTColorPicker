local generator = function (image, items)
    local str = "x, y = screen.find_color("
    local extraEndings = ""
    str = str .. "{\n"
    for _, a in ipairs(items) do
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
    uuid = "0D7B59F5-4F47-4EDA-B4B0-F0A047C1784D",
    name = "\xe2\x80\x8b\xe2\x80\x8b\xe2\x80\x8bXXTouch 多点相似度模式找色",
    version = "1.0",
    platformVersion = "2.2",
    author = "xtzn",
    extension = "lua",
    enabled = true,
    previewable = true,
    generator = generator,
}
