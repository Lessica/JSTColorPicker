# JSTColorPicker
Pick color, location, and area from PNG screenshots (i.e. image annotation). This tool uses [sRGB IEC61966-2.1](https://en.wikipedia.org/wiki/SRGB) as its color space.


## Features
- Pick colors & areas from PNG screenshots
- Read/Write annotator data from/into EXIF dictionary of PNG files
- Take screenshots directly from iOS devices (depends `libimobiledevice`)
- Copy/Export annotator data using custom templates


## TODOs
- Take screenshots from Android devices


## Usage

### Magic Cursor
- `⌘↵` / **Tap** (or **Click** if *Force Touch* is enabled): Add current *coordinate & color* to content list.
- `⇧` + **Drag** (or **Drag** if *Force Touch* is enabled): Add dragged *area* to content list.
- `⌘⌫`: Delete *coordinate & color* at current position or *area* contains current position.
- **Hold** `⌘`: Switch to *Selection Arrow* temporarily.

### Magnifying Glass
- **Click**: Magnify to next level from current position.
- `⇧` + **Drag** (or **Drag** if *Force Touch* is enabled): Magnify to fill window with dragged area.
- **Hold** `⌘`: Switch to *Magic Cursor* temporarily.
- **Hold** `⌥`: Switch to *Minifying Glass* temporarily.

### Minifying Glass
- **Click**: Minify to previous level from current position.
- **Hold** `⌘`: Switch to *Magic Cursor* temporarily.
- **Hold** `⌥`: Switch to *Magnifying Glass* temporarily.

### Selection Arrow
- **Hold** `⌘`: Switch to *Magic Cursor* temporarily.

### Move
- **Drag**: A simple drag-to-move operation for common mouse device.
- **Hold** `⌘`: Switch to *Magic Cursor* temporarily.
- **Move with two fingers**: Standard drag operation for Magic Mouse / Trackpad.
- **Pinch with two fingers**: Zoom in or out.
- `⌘` + `↑ ↓ ← →`: Move cursor by 1 pixel.
- `⇧⌘` + `↑ ↓ ← →`: Move cursor by 10 pixels.
- `⌃⌘` + `↑ ↓ ← →`: Move cursor by 100 pixels.

### Fit Window / Fill Window
There's no need to explain.

### Annotator Management
- Select one or more item(s) from left content list.
- Right click to show menu for selected item(s).
- `0123456789`: Enter item `ID` to select existing item quickly.

### Export
- `⌘E`: Export all items using selected template.

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
- `⌘S` Save...
- `⇧⌘S` Save As...
- `⇧⌘D` Compare Opened Documents

### Edit
- `⌘Z` Undo
- `⇧⌘Z` Redo
- `⌫` Delete
- `⌘A` Select All

### View
- `⌥⌘T` Show/Hide Toolbar
- `⌃⌘S` Show/Hide Sidebar
- `⌃⌘F` Enter/Exit Full Screen
- `⌃⌘G` **Toggle Color Grid**
- `⌃⌘C` **Toggle Color Panel**

### Devices
- `⌥⌘S` **Screenshot**

### Window
- `⌘M` Minimize
- `⌃⇧⇥` Show Previous Tab
- `⌃⇥` Show Next Tab
- `⇧⌘\` Show All Tabs

### Help
- `⌘?` JSTColorPicker Help


## Toolbar Key Equivalents
- `⌃F1` Open...
- `⌃F2` *Magic Cursor*
- `⌃F3` *Magnifying Glass*
- `⌃F4` *Minifying Glass*
- `⌃F5` *Selection Arrow*
- `⌃F6` *Move*
- `⌃F7` Fit Window
- `⌃F8` Fill Window


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

