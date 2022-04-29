local curl = require("cURL.safe")
local json = require("cjson")
local apiBase = "http://127.0.0.1:8000/"

local generator = function (image, content, action)
    if action == "preview" then
        return "markdown", "双击此处渲染示例护照\n\n按下 **⇧⌘D** 以退出比较模式"
    end

    if action == "doubleCopy" then
        local imageData = image.get_data(true)
        local mime
        if image.extension == "png" then
            mime = "image/png"
        else
            mime = "image/jpeg"
        end

        local savedPath = image['path']..".render.jpg"
        local renderObj = io.open(savedPath, "w")
        local curlObj = curl.easy()
            :setopt_url(apiBase.."imagick/render/?scale=1&quality=1")
            :setopt_headerfunction(print)
            :setopt_writefunction(renderObj)
            :setopt_httppost(
                curl.form()
                    :add_buffer("Image", image.filename, imageData, mime)
                    :add_content("Passport Type", "P")
                    :add_content("Passport Code", "USA")
                    :add_content("Passport Number", "752671441")
                    :add_content("Surname / Last Name", "MOOREHEAD")
                    :add_content("Given Names / First Name", "RICO")
                    :add_content("Nationality", "United States of America")
                    :add_content("Date of Birth", "17/07/1973")
                    :add_content("Place of Birth", "Illinois, USA")
                    :add_content("Date of Issue", "25 FEB 2017")
                    :add_content("Date of Expiration", "25 FEB 2027")
                    :add_content("Endorsements", "SEE PAGE 27")
                    :add_content("Sex", "M")
                    :add_content("Authority", "United States\nDepartment of State")
                    :add_content("Signature", "Rico Moorehead")
                    :add_content("Machine Readable Zone", "P<USAMOOREHEAD<<RICO<<<<<<<<<<<<<<<<<<<<<<<<\n4558349664USA7307177F2703051709733321<313822")
            )
            :perform()
        local statusCode = curlObj:getinfo(curl.INFO_RESPONSE_CODE)
        curlObj:close()
        
        renderObj:close()
        if statusCode == 200 then
            return "comparison", savedPath
        else
            renderObj = io.open(savedPath, "r")
            retObj = json.decode(renderObj:read())
            renderObj:close()
            return "prompt", "验证失败："..retObj["reason"]
        end
    end

    return "prompt", "不支持的动作"
end

return {
    uuid = "F02A36D9-EA7A-492D-A91F-6C07B0B757CA",
    name = "\x02BatchImagick 即时渲染（护照）",
    version = "1.1",
    platformVersion = "2.12",
    author = "Lessica",
    description = "将标注底板及示例输入上传至 AdHoc 服务器，验证其有效性并进行实时渲染，随后将渲染结果与当前文档进行差异比对。",
    extension = "txt",
    async = true,
    saveInPlace = true,
    generator = generator,
    enabled = true,
    previewable = true,
}
