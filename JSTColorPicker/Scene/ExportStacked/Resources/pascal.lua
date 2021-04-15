local lupa = require "lupa"

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
        </bndbox>
    </object>
{% endfor %}
</annotation>]]

local _saveInPlace = true

local generator = function (image, ...)
    local objects = {...}
    local newObjects = {}
    for k, v in ipairs(objects) do
        v['pose'] = 'Unspecified'
        v['truncated'] = 0
        v['difficult'] = 0
        newObjects[k] = v
    end
    image['objects'] = newObjects
    image['database'] = 'Unknown'
    image['depth'] = 3
    image['segmented'] = 0
    local outputContent = lupa.expand(template, image)
    if _saveInPlace then
        local outputPath = image['path'] .. '.xml'
        local outputFile = assert(io.open(outputPath, "w"))
        outputFile:write(outputContent)
        outputFile:close()
    end
    return outputContent
end

return {
    uuid = "C4B5891D-1D60-43CC-A93F-71E3C42D735F",    -- required, a unique UUID4 identifier
    name = "PASCAL VOC",                              -- required, name only for display
    version = "1.0",                                  -- required, same template with earlier version will not be displayed
    platformVersion = "2.2",                          -- optional, minimum required software version
    author = "Lessica",                               -- optional, the author of this template script
    description = "The XML format for PASCAL Visual Object Classes.",
    extension = "xml",                                -- optional, file extension used for exporting
    async = true,                                     -- if it takes a long time to generate content, set this to `true` to avoid user interface blocking
    saveInPlace = _saveInPlace,                       -- if the content generator is responsible for handling the export of content, set this to `true`
    generator = generator,                            -- required, the content generator
}
