# JSTColorPicker
Pick color, location, and area from PNG screenshots (i.e. image annotation). This tool uses [sRGB IEC61966-2.1](https://en.wikipedia.org/wiki/SRGB) as its color space.


## Features
- Pick colors & areas from PNG screenshots
- Read/Write annotation data from/into EXIF dictionary of PNG files
- Take screenshots directly from iOS devices (based on [`libimobiledevice`](https://github.com/libimobiledevice/libimobiledevice))
- Copy/Export annotation data using custom templates
- Show the difference between screenshots


## TODOs
- Take screenshots from Android devices


## Usage

### Magic Cursor
- `⌘↵` / **Click / Tap** (or **Click** if *Force Touch* is enabled): Add current *coordinate & color* to content list.
- `⇧` + **Drag** (or **Drag** if *Force Touch* is enabled): Add dragged *area* to content list.
- `⌘⌫`: Delete *coordinate & color* at current position or the top most *area* contains current position.
- **Right Click / Tap with two fingers** (or **Click with two fingers** if *Force Touch* is enabled): Delete *coordinate & color* at current position or the top most *area* contains current position.
- `⌥` + **Right Click / Tap with two fingers** (or **Click with two fingers** if *Force Touch* is enabled): Display a menu with all annotations cascading under the current position, select one to delete the annotation.
- **Hold** `⌃`: Switch to *Selection Arrow* temporarily.

### Selection Arrow
- **Click / Tap** (or **Click** if *Force Touch* is enabled): Select *coordinate & color* at current position or the top most *area* contains current position.
- `⌘` + **Click / Tap** (or **Click** if *Force Touch* is enabled): Select *coordinate & color* at current position or the top most *area* contains current position, while keeping the previous selections.
- `⇧` + **Click / Tap** (or **Click** if *Force Touch* is enabled): Select *coordinate & color* at current position or all *areas* contains current position, while keeping the previous selections.
- `⌥` + **Click / Tap** (or **Click** if *Force Touch* is enabled): Display a menu with all annotations cascading under the current position, select one to select the annotation, while keeping the previous selections.
- **Right Click / Tap with two fingers** (or **Click with two fingers** if *Force Touch* is enabled): Delete *coordinate & color* at current position or the top most *area* contains current position.
- `⌥` + **Right Click / Tap with two fingers** (or **Click with two fingers** if *Force Touch* is enabled): Display a menu with all annotations cascading under the current position, select one to delete the annotation.
- **Drag** (or **Drag** if *Force Touch* is enabled): Modify *coordinate & color* to a new position, or modify *area* to a new dimension.
- **Hold** `⌃`: Switch to *Magic Cursor* temporarily.

### Magnifying Glass
- **Click**: Magnify to next level from current position.
- `⇧` + **Drag** (or **Drag** if *Force Touch* is enabled): Magnify to fill window with dragged area.
- **Hold** `⌃`: Switch to *Magic Cursor* temporarily.
- **Hold** `⌥`: Switch to *Minifying Glass* temporarily.

### Minifying Glass
- **Click**: Minify to previous level from current position.
- **Hold** `⌃`: Switch to *Magic Cursor* temporarily.
- **Hold** `⌥`: Switch to *Magnifying Glass* temporarily.

### Move
- **Drag**: A simple drag-to-move operation for common mouse device.
- **Hold** `⌃`: Switch to *Magic Cursor* temporarily.

### General Shortcuts
- **Move with one finger**: Standard move operation (Magic Mouse).
- **Move with two fingers**: Standard move operation (Magic Trackpad).
- **Pinch with two fingers**: Zoom in or out (Magic Trackpad).
- **Double Tap with one fingers**: Smart Zoom in or out (Magic Mouse).
- **Double Tap with two fingers**: Smart Zoom in or out (Magic Trackpad).
- `⌘` + `↑ ↓ ← →`: Move cursor by 1 pixel.
- `⇧⌘` + `↑ ↓ ← →`: Move cursor by 10 pixels.
- `⌃⌘` + `↑ ↓ ← →`: Move cursor by 100 pixels.
- `⌘-`: **Zoom in** with the current cursor position (if the cursor is outside the scene, the scene is zoomed in with the center point).
- `⌘=`: **Zoom out** with the current cursor position (if the cursor is outside the scene, the scene is zoomed out with the center point).
- `⌘[`: If the selected *annotation* is the only selected *annotation* in all levels under the current cursor position, the selected state is switched to the previous *annotation* in the cascade under the current cursor position.
- `⌘]`: If the selected *annotation* is the only selected *annotation* in all levels under the current cursor position, the selected state is switched to the next *annotation* in the cascade under the current cursor position.

### Ruler
- **Drag** (or **Drag** if *Force Touch* is enabled): Modify *coordinate & color* to a new position, or modify *area* to a new dimension.

### Fit Window / Fill Window
There's no need to explain.

### Annotation Management
- Select one or more item(s) from left content list.
- Right click to show menu for selected item(s):
  * `↵`: Scroll the scene to the selected annotation, and adjust the scale to fit its size.
  * `⌘C`: Copy: Copy these annotations with current template.
  * `⌘V`: Paste: Paste annotations from another document.
  * `⌘T`: Smart Trim: Trim this area with Canny edge detection algorithm.
  * `⌥⌘E`: Export As: Export these annotations with current template.
  * `⌥⌘R`: Resample: Save this area to a PNG file.
  * `⌘A`: Select All
  * `⌫`: Delete
- `0123456789`: Enter item `ID` to select existing item quickly.
- Type a string in the following format into the input box in the bottom left corner and type **Enter** to add or locate an item. Right-click `+` to toggle the data entry format.
  * *coordinate & color*: `(x, y)`
  * *area*: `(x1, y1, x2, y2)`
  * *area*: `(x, y, w, h)`

### Others
- <code>⌘`</code>: Copy the *coordinate & color* at the cursor location directly to the general pasteboard.


## Menu Key Equivalents

### JSTColorPicker
- `⌘,` Preferences...
- `⌘H` Hide JSTColorPicker
- `⌥⌘H` Hide Others
- `⌘Q` Quit JSTColorPicker

### File
- `⌘N` New
- `⌘O` Open...
- `⌘W` Close
- `⌘S` Save
- `⇧⌘S` Save As...
- `⇧⌘D` Compare Opened Documents
- `⇧⌘C`: Copy all annotations using selected template.
- `⇧⌘E`: Export all annotations using selected template.

### Edit
- `⌘Z` Undo
- `⇧⌘Z` Redo
- `⌘C` Copy: Copy these annotations with current template.
- `⌘V` Paste: Paste annotations from another document.
- `⌘T` Smart Trim: Trim this area with Canny edge detection algorithm.
- `⌥⌘E` Export As: Export these annotations with current template.
- `⌥⌘R` Resample: Save this area to a PNG file.
- `⌘A` Select All
- `⌫` Delete

### View
- `⌥⌘T` Show/Hide Toolbar
- `⌃⌘S` Show/Hide Sidebar
- `⌃⌘F` Enter/Exit Full Screen
- `⌃⌘G` **Toggle Color Grid**
- `⌃⌘C` **Toggle Color Panel**

### Devices
- `⌃S` **Screenshot**
- `⌃I` **Discovery Devices**

### Templates
- `⌃⌘` + `123456789`: Switch between templates.
- `⌃⌘0` *Reload All Templates*
- `⌃⌘F` *Show Templates...*: Show all templates in Finder.
- `⌃⌘L` *Show Logs...*: Open *Console.app* to watch all exceptions and warnings thrown from templates loading.

### Window
- `⌘M` Minimize
- `⌃⇧⇥` Show Previous Tab
- `⌃⇥` Show Next Tab
- `⇧⌘\` Show All Tabs

### Help
- `⌘?` JSTColorPicker Help


## Toolbar Key Equivalents
- `[Fn]F1` Open...
- `[Fn]F2` *Magic Cursor*
- `[Fn]F3` *Magnifying Glass*
- `[Fn]F4` *Minifying Glass*
- `[Fn]F5` *Selection Arrow*
- `[Fn]F6` *Move*
- `[Fn]F7` Fit Window
- `[Fn]F8` Fill Window


## Customizable Templates

JSTColorPicker uses [Lua 5.3.4](https://www.lua.org/) as its template engine.

Click the *export option* button at the bottom right of window, you will see available templates in `templates` folder. Click `Show Templates...` will show that folder in Finder. The name of template file should end up with path extension `.lua`. Selected template will be applied to all copy/export actions if possible.

### Write Templates

*Template* is a *Lua* script which simply returns a table:
```lua
return {
    uuid = "0C2E7537-45A6-43AD-82A6-35D774414A09",  --required, a unique UUID4 identifier
    name = "Example",  -- required, name only for display
    version = "0.1",  -- required, same template with earlier version will not be displayed
    platformVersion = "1.6",  -- minimum required software version
    author = "Lessica",
    description = "This is an example of JSTColorPicker export script.",
    extension = "lua",  -- file extension used for exporting
    generator = generator,  -- required
}
```

`generator` is a lua function which will be executed when you copy or export item(s):
```lua
local generator = function (image, ...)
    --
    local args = {...}
    --
end
```

`image` is a lua table which represents the opened image document in current window:
  - `image.w`: image width in pixels
  - `image.h`: image height in pixels
  - `image.get_color(x, y)`: returns **argb** integer value of color
  - `image.get_image(x, y, w, h)`: returns cropped image's PNG data representation

`args` is a lua sequence of *coordinate & color* and *area*:
* *coordinate & color*:
  - `color.id`
  - `color.similarity`
  - `color.x`
  - `color.y`
  - `color.color`: **argb** integer value of color
* *area*:
  - `area.id`
  - `area.similarity`
  - `area.x`
  - `area.y`
  - `area.w`: area width in pixels
  - `area.h`: area height in pixels

Test the existence of `item.w` to check if the item is a *coordinate & color* or an *area*.

## LICENSE
- [JSTColorPicker](https://github.com/Lessica/JSTColorPicker/blob/master/LICENSE)
- [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice/blob/master/COPYING.LESSER)
- [MASPreferences](https://github.com/shpakovski/MASPreferences/blob/master/LICENSE.md)
- [Sparkle](https://github.com/sparkle-project/Sparkle/blob/master/LICENSE)

