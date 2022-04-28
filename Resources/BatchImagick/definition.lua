local curl = require("cURL")
local json = require("cjson")
local apiBase = "http://127.0.0.1:8000/"

local generator = function (image, content, action)
    if action == "preview" then
        return "markdown", "双击此处更新标签定义"
    end

    if action == "doubleCopy" then
        function json_definition_list()
            local tmpObj = io.tmpfile()
            local curlObj = curl.easy()
                :setopt_url(apiBase.."imagick/definition/")
                :setopt_writefunction(tmpObj)
                :perform()
            local status = curlObj:getinfo(curl.INFO_RESPONSE_CODE)
            curlObj:close()
            tmpObj:seek("set", 0)
            local response = json.decode(tmpObj:read())
            tmpObj:close()
            return status, response
        end
        function download_definition_list(def_id, def_path)
            local tmpObj = io.open(def_path, "wb")
            local curlObj = curl.easy()
                :setopt_url(apiBase.."imagick/definition/"..tostring(math.floor(def_id)).."/")
                :setopt_writefunction(tmpObj)
                :perform()
            local status = curlObj:getinfo(curl.INFO_RESPONSE_CODE)
            curlObj:close()
            tmpObj:close()
            return status
        end
        local statusCode, retObj = json_definition_list()
        if statusCode == 200 then
            local applicationSupportDirectory = _G["applicationSupportDirectory"]
            local retClasses = retObj["classes"]
            local succeedCount = 0
            for i in pairs(retClasses) do
                local downloadName = retClasses[i]["name"]
                local downloadPath = applicationSupportDirectory.."/Definitions/"..downloadName..".plist"
                local downloadStatus = download_definition_list(retClasses[i]["id"], downloadPath)
                if downloadStatus == 200 then
                    succeedCount = succeedCount + 1
                else
                    os.remove(downloadPath)
                end
            end

            return "prompt", "获取标签定义列表成功，共计 "..tostring(#retObj["classes"]).." 个标签定义，成功 "..tostring(succeedCount).." 个。"
        else
            return "prompt", "获取标签定义列表失败："..retObj["reason"]
        end
    end

    return "prompt", "不支持的动作"
end

return {
    uuid = "355E89E4-4C6D-433D-9B24-DC76BAFF0CE0",
    name = "\x04BatchImagick 更新定义",
    version = "1.1",
    platformVersion = "2.12",
    author = "Lessica",
    description = "从 AdHoc 服务器下载完整标签定义列表。",
    extension = "txt",
    async = true,
    saveInPlace = true,
    generator = generator,
    enabled = true,
    previewable = true,
}
