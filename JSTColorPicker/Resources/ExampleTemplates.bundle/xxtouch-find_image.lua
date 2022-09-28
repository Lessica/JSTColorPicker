local generator = function (image, items)
    local processed = false
    local str = "x1, y1, x2, y2, sim = screen.find_image("
    local extraEndings = ""
    str = str .. "\""
    for _, a in ipairs(items) do
        if a.width ~= nil then
            str = str .. image.get_image(a.minX, a.minY, a.width, a.height):gsub(".", function (c)
                return string.format("\\x%02x", string.byte(c))
            end)
            extraEndings = ", " .. string.format("%6.2f", a.similarity * 100.0)
            processed = true
            break
        end
    end
    str = str .. "\"" .. extraEndings .. ")"
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
