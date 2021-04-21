local generator = function (image, items)
    local similarity = 0.9
    local str = "if (screen.is_colors("
    str = str .. "{\n"
    for _, a in ipairs(items) do
        if a.color ~= nil then
            str = str .. "  { " .. string.format("%4d", a.x) .. ", " .. string.format("%4d", a.y) .. ", " .. string.format("0x%06x", a.color & 0xffffff).. " },  -- " .. tostring(a.id) .. "\n"
        end
        if a.similarity < similarity then
            similarity = a.similarity
        end
    end
    str = str .. "}, " .. tostring(similarity * 100) .. ")) then"
    return str
end

return {
    uuid = "815BC1C6-67E6-4AED-A5BA-99474CD8C42C",
    name = "\xe2\x80\x8b\xe2\x80\x8bXXTouch 屏幕多点颜色匹配",
    version = "1.0",
    platformVersion = "2.2",
    author = "xtzn",
    extension = "lua",
    enabled = true,
    previewable = true,
    generator = generator,
}
