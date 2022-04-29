local curl = require("cURL.safe")
local json = require("cjson")
local apiBase = "http://127.0.0.1:8000/"

local generator = function (image, content, action)
    if action == "preview" then
        return "markdown", "双击上传底板 _`"..image.filename.."`_\n\n同文件名的底板将会覆盖现有数据"
    end

    if action == "doubleCopy" then
        local imageData = image.get_data(true)
        local mime
        if image.extension == "png" then
            mime = "image/png"
        else
            mime = "image/jpeg"
        end

        local tmpObj = io.tmpfile()
        local curlObj = curl.easy()
            :setopt_url(apiBase.."imagick/upload/?deep=1&override=1")
            :setopt_writefunction(tmpObj)
            :setopt_httppost(
                curl.form()
                    :add_buffer("Image", image.filename, imageData, mime)
            )
            :perform()
        local statusCode = curlObj:getinfo(curl.INFO_RESPONSE_CODE)
        curlObj:close()

        tmpObj:seek("set", 0)
        local retObj = json.decode(tmpObj:read())
        tmpObj:close()

        if statusCode == 200 then
            return "prompt", "上传成功"
        else
            return "prompt", "上传失败："..retObj["reason"]
        end
    end

    return "prompt", "不支持的动作"
end

return {
    uuid = "77FC89F1-DA30-4E12-9E64-ED1FF625260F",
    name = "\x03BatchImagick 上传底板",
    version = "1.1",
    platformVersion = "2.12",
    author = "Lessica",
    description = "将标注底板上传至 AdHoc 服务器，验证其有效性并写入数据库。",
    extension = "txt",
    async = true,
    saveInPlace = true,
    generator = generator,
    enabled = true,
    previewable = true,
}
