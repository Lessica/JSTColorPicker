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
    return lupa.expand(template, image)
end

return {
    uuid = "C4B5891D-1D60-43CC-A93F-71E3C42D735F",
    name = "PASCAL VOC",
    version = "1.0",
    platformVersion = "2.2",
    author = "Lessica",
    description = "The XML format for PASCAL Visual Object Classes.",
    extension = "xml",
    async = true,
    generator = generator,
}
