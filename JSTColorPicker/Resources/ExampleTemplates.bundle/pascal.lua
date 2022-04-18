local lupa = require("lupa")
local xml2lua = require("xml2lua")
local json = require("cjson")
local curl = require("cURL")

local template = [[<annotation>
    <folder>{{ folder }}</folder>
    <filename>{{ filename }}</filename>
    <path>{{ path }}</path>
    <source>
        <database>{{ database }}</database>
    </source>
    <size>
        <width>{{ width }}</width>
        <height>{{ height }}</height>
        <depth>{{ depth }}</depth>
    </size>
    <segmented>{{ segmented }}</segmented>
{% for object in objects %}    <object>
        <name>{{ object.name }}</name>
        <pose>{{ object.pose }}</pose>
        <truncated>{{ object.truncated }}</truncated>
        <difficult>{{ object.difficult }}</difficult>
        <bndbox>
            <xmin>{{ object.minX }}</xmin>
            <ymin>{{ object.minY }}</ymin>
            <xmax>{{ object.maxX }}</xmax>
            <ymax>{{ object.maxY }}</ymax>
        </bndbox>{{ object.userInfoXML }}
    </object>
{% endfor %}</annotation>]]

local _saveInPlace = true

local generator = function (image, items, action)
    local newObjects = {}
    for k, v in ipairs(items) do
        if v.userInfo ~= nil then
            v['userInfoXML'] = '\n        ' .. xml2lua.toXml(v.userInfo, 'userInfo'):sub(1, -2):gsub("[\n]", "\n        ")
        else
            v['userInfoXML'] = ''
        end
        if v.width ~= nil then
            v['pose'] = 'Unspecified'
            v['truncated'] = 0
            v['difficult'] = 0
            newObjects[k] = v
        end
    end
    image['objects'] = newObjects
    image['database'] = 'Unknown'
    image['depth'] = 3
    image['segmented'] = 0
    local outputContent = lupa.expand(template, image)
    if _saveInPlace then
        -- HTTP Post
        if action == "doubleCopy" then
            curl.easy()
                :setopt_url('https://httpbin.org/post')
                :setopt_writefunction(io.write)
                :setopt_httppost(
                    curl.form() -- Lua-cURL guarantee that form will be alive
                        :add_buffer("test_file", "test_file.xml", outputContent, "text/xml")
                )
                :perform()
                :close()
        elseif action == "export" then
            image['get_color'] = nil
            image['get_image'] = nil
            image['_LUPAFILENAME'] = nil
            image['_LUPAPOSITION'] = nil
            image['_LUPASOURCE'] = nil
            
            outputPath = image['path'] .. '.json'
            outputFile = assert(io.open(outputPath, "w"))
            outputFile:write(json.encode(image))
            outputFile:close()
            
            local outputPath, outputFile
            outputPath = image['path'] .. '.xml'
            outputFile = assert(io.open(outputPath, "w"))
            outputFile:write(outputContent)
            outputFile:close()
        end
    end
    return outputContent
end

return {
    uuid = "C4B5891D-1D60-43CC-A93F-71E3C42D735F",    -- required, a unique UUID4 identifier
    name = "PASCAL VOC",                              -- required, name only for display
    version = "1.1",                                  -- required, same template with earlier version will not be displayed
    platformVersion = "2.11",                         -- optional, minimum required software version
    author = "Lessica",                               -- optional, the author of this template script
    description = "The XML format for _PASCAL Visual Object Classes_.",
    extension = "xml",                                -- optional, file extension used for exporting
    async = true,                                     -- if it takes a long time to generate content, set this to `true` to avoid user interface blocking
    saveInPlace = _saveInPlace,                       -- if the content generator is responsible for handling the export of content, set this to `true`
    generator = generator,                            -- required, the content generator
    enabled = true,                                   -- optional
    previewable = true,                               -- optional
}
