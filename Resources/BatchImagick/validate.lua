local curl = require("cURL.safe")
local json = require("cjson")
local apiBase = "http://127.0.0.1:8000/"

local generator = function (image, content, action)
    if action == "preview" then
        return "markdown", "双击此处验证标注数据"
    end

    if action == "doubleCopy" then
        local archivedData = content.get_data()
        local tmpObj = io.tmpfile()
        curl.easy()
            :setopt_url(apiBase.."imagick/validate/?deep=1")
            :setopt_writefunction(tmpObj)
            :setopt_httppost(
                curl.form()
                    :add_buffer("content", "content.plist", archivedData, "text/xml")
            )
            :perform()
            :close()
        tmpObj:seek("set", 0)
        local retObj = json.decode(tmpObj:read())
        tmpObj:close()

        if retObj["validated"] == true then
            return "prompt", "验证成功，共计 "..tostring(#retObj["content"]["items"]).." 个有效标注。"
        else
            return "prompt", "验证失败："..retObj["reason"]
        end
    end

    return "prompt", "不支持的动作"
end

return {
    uuid = "E4F53C81-9072-4830-A9CD-D905A88DD3C1",
    name = "\x01BatchImagick 验证",
    version = "1.1",
    platformVersion = "2.12",
    author = "Lessica",
    description = "以 **`NSKeyedArchiver`** 协议封装标注数据，上传至 AdHoc 服务器，并验证其有效性。",
    extension = "txt",
    async = true,
    saveInPlace = true,
    generator = generator,
    enabled = true,
    previewable = true,
}
