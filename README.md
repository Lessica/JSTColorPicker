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

### Item Selection
- Select item(s) from left content list.
- `0123456789`: Enter item `ID` to select existing item.

### Item Modification
1. Select an item.
2. Modify item *coordinate* or *area* by moving ruler markers.

### Item Export
- `⌘E`: Export all items using selected template.

### Others
- <code>⌘`</code>: Copy the *coordinate & color* at the cursor location directly to the general pasteboard.

