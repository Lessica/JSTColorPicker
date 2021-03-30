#!/bin/env python3

import requests
import pathlib


def markdown_render(md):
    url = 'https://api.github.com/markdown/raw'
    res = requests.post(url, data = md.encode('utf-8'), headers = {'Content-Type': 'text/x-markdown'})

    head = """<!DOCTYPE html>
<html>

<head>
    <meta charset="utf-8">
    <title>JSTColorPicker</title>
    <link rel="stylesheet" href="../github-markdown.css">
</head>

<body class="markdown-body">
"""

    body = res.text

    foot = """
</body>

</html>
"""

    return head + body + foot


def markdown_map(input_path, output_path):
    with open(input_path, 'r') as input_file:
        md_content = input_file.read()
        html_content = markdown_render(md_content)
        with open(output_path, 'wb') as out:
            out.write(html_content.encode('utf-8'))
            out.close()


def markdown_do(root_path):
    for markdown_path in root_path.glob('*.md'):
        lang = 'en'
        name_arr = markdown_path.stem.split('_')
        if len(name_arr) == 2:
            lang = name_arr[1]
        add_path = 'JSTColorPicker/Help/' + lang + '.lproj/JSTColorPicker.html'
        markdown_map(markdown_path, root_path / add_path)


if __name__ == "__main__":
    root_path = pathlib.Path(__file__).parent.parent.absolute()
    markdown_do(root_path)

