# JSTColorPicker
There are (so many) macOS color pickers for designers. But a few of them picks color together with the location from PNG screenshots (i.e. image annotation).


## Screenshots
![v1.7-2](https://raw.githubusercontent.com/Lessica/JSTColorPicker/master/screenshots/v1.7-2.png?raw=true)


## Features
- Pick colors & areas from PNG screenshots
- Read/Write annotator data from/into EXIF dictionary of PNG files
- Take screenshots directly from iOS devices (depends `libimobiledevice`)
- Copy/Export annotator data using custom templates


## TODOs
- Drag to move/resize annotators
- Take screenshots from Android devices


## Usage

### Magic Cursor
- `⌘↵` / **Click** (or **Deep Click** if *Force Touch* is enabled): Add current *coordinate & color* to content list.
- `⇧` + **Drag** (or **Deep Drag** if *Force Touch* is enabled): Add dragged *area* to content list.
- `⌘⌫`: Delete *coordinate & color* at current position or *area* contains current position.

### Magnifying Glass
- **Click**: Magnify to next level from current position.
- `⇧` + **Drag** (or **Deep Drag** if *Force Touch* is enabled): Magnify to fill window with dragged area.
- **Hold** `⌘`: Switch to *Magic Cursor* temporarily.
- **Hold** `⌥`: Switch to *Minifying Glass* temporarily.

### Minifying Glass
- **Click**: Minify to previous level from current position.
- **Hold** `⌘`: Switch to *Magic Cursor* temporarily.
- **Hold** `⌥`: Switch to *Magnifying Glass* temporarily.

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

### Item Actions
- Select item(s) from left content list.
- Right click to show menu for selected item(s).
- `0123456789`: Enter item `ID` to select existing item quickly.
- Modify item *coordinate* or *area* by moving its ruler markers.

### Export
- `⌘E`: Export all items using selected template.

### Others
- <code>⌘`</code>: Copy the *coordinate & color* at the cursor location directly to the general pasteboard.


## Menu Key Equivalents

### JSTColorPicker
- `⌘,` Preferences
- `⌘H` Hide JSTColorPicker
- `⌥⌘H` Hide Others
- `⌘Q` Quit

### File
- `⌘N` New
- `⌘O` Open...
- `⌘W` Close
- `⌘S` Save...
- `⇧⌘S` Save As...

### Edit
- `⌘Z` Undo
- `⇧⌘Z` Redo
- `⌫` Delete
- `⌘A` Select All

### View
- `⇧⌘\` Show All Tabs
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

### Help
- `⌘?` JSTColorPicker Help


## Toolbar Key Equivalents
- `⌃F1` Open...
- `⌃F2` Cursor
- `⌃F3` Magnifying Glass
- `⌃F4` Minifying Glass
- `⌃F5` Move
- `⌃F6` Fit Window
- `⌃F7` Fill Window


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

`args` is a lua sequence of *colors* and *areas*:
* *color* item:
  - `color.id`
  - `color.similarity`
  - `color.x`
  - `color.y`
  - `color.color`: **argb** integer value of color
* *area* item:
  - `area.id`
  - `area.similarity`
  - `area.x`
  - `area.y`
  - `area.w`: area width in pixels
  - `area.h`: area height in pixels

Test the existence of `item.w` to check if the item is a *color* or an *area*.

### Debug Templates

To view template logs, you have to build and install JSTColorPicker from source code, then click `Show Logs...` from the *export option* menu, search for process `JSTColorPicker` in the `Console.app`.

Click `Reload All Templates` will reply all changes you made to the `templates` folder immediately.

