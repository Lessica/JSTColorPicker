local generator = function (image, items)
    local function chunk(text, size)
        local s = {}
        for i = 1, #text, size do
            s[#s + 1] = text:sub(i, i + size - 1)
        end
        return s
    end
    local processed = false
    local str = "x, y = screen.find_image("
    local extraEndings = ""
    str = str .. "[[\n"
    for _, a in ipairs(items) do
        if a.width ~= nil then
            str = str .. table.concat(chunk(image.get_image(a.minX, a.minY, a.width, a.height):gsub(".", function (c)
                return string.format("\\x%02x", string.byte(c))
            end), 32), "\n")
            extraEndings = ", " .. string.format("%6.2f", a.similarity * 100.0) .. ", " .. tostring(a.minX) .. ", " .. tostring(a.minY) .. ", " .. tostring(a.maxX) .. ", " .. tostring(a.maxY)
            processed = true
            break
        end
    end
    str = str .. "\n]]" .. extraEndings .. ")"
    if processed then
        return str
    end
    error("未选中有效图像区域")
end

return {
    uuid = "6A9FF9FC-701B-4A2D-A79D-BE5E1E805FC0",
    name = "\xe2\x80\x8b\xe2\x80\x8b\xe2\x80\x8b\xe2\x80\x8bXXTouch 屏幕找图",
    version = "1.0",
    platformVersion = "2.12",
    author = "xtzn",
    extension = "lua",
    enabled = true,
    previewable = true,
    generator = generator,
    colorSpace = "sRGB",
}
