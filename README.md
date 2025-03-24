# Startile

Simple tile editor made in [Zig](https://ziglang.org/) using [raylib](https://raylib.com)

It is the second tool from a set created for ROM hacking (any file in reality). The other two are:

- [Stardust](https://github.com/SultansOfCode/Stardust): a simple hexadecimal editor with extra features like symbols' table and relative search
- [Starpatch](https://github.com/SultansOfCode/Starpatch): a simple file patcher

All these projects were developed to better learn Zig and raylib

<div style="text-align: center">
  <img alt="Main screen" src="https://github.com/SultansOfCode/Startile/blob/main/docs/main_screen.png?raw=true" />
</div>

## Building

Simply clone/download this repository and run:

```
$ zig build
```

## Using

### Opening a file

Drag and drop the desired file into the application. No prompt will be emitted, so you will lose anything that was not saved

### Toolbar

#### Tiles window

- Pixel size: adjust the pixel size inside tiles' window
- Show grid: enable/disable grid inside tiles' window

#### Clipboard window

- Pixel size: adjust the pixel size inside clipboard window
- Show grid: enable/disable grid inside clipboard window

#### Editor window

- Pixel size: adjust the pixel size inside editor window
- Show grid: enable/disable grid inside editor window
- Square size: how many square tiles will have inside editor window (1x1, 2x2, 3x3 or 4x4)

#### File

- Pixel mode: how the file will be encoded/decoded
- Offset: adjust byte alignment
- Save button: saves the file

#### Application

- Style: changes the application's style

### Working area

#### Tiles window

Shows the file's tiles decoded with the selected pixel mode and allows you to get/set tiles

#### Clipboard window

A clipboard area to save tiles while working with them

#### Editor window

The area to edit the tiles

#### Pallete window

The pallete for the current selected pixel mode

- Cog wheel: allow you to edit the pallete's colors
  - Set FG: set the current color picked to the foreground color (overrides the pallete)
  - Set BG: set the current color picked to the background color (overrides the pallete)
- Swap: swap foreground and background colors

#### Active tile window

Select the working tile inside the editor window (so Tiles window and Clipboard window will reference to this tile)

### Keyboard

- Up: moves tiles window one line up
- Down: moves tiles window one line down
- Page Up: moves tiles window one screen up
- Page Down: moves tiles window one screen down
- +: increases offset
- -: decreases offset
- Ctrl + Home: moves tiles window to the start of the file
- Ctrl + End: moves tiles window to the end of the file

### Mouse

- Scroll: scrolls tiles window up/down

#### Tiles window

- Left click: puts the clicked tile into the active tile
- Right click: puts the active tile into the clicked tile

#### Clipboard window

- Left click: puts the clicked tile into the active tile
- Right click: puts the active tile into the clicked tile

#### Editor window

- Left click: fills the pixel at mouse position with foreground color
- Right click: fills the pixel at mouse's position with background color

#### Pallete window

- Left click: selects the foreground color
- Right click: selects the background color
- Mouse over: when not in editing mode, shows the RGB and index of the color at mouse's position

#### Active tile window

- Mouse over: shows the tiles' indexes and which one is currently active

### Thanks

People from [Twitch](https://twitch.tv/SultansOfCode) for watching me and supporting me while developing it

People from #Zig channel at [Libera.Chat](https://libera.chat/) for helping me out with Zig doubts

All of my [LivePix](https://livepix.gg/sultansofcode) donators

---

### Sources and licenses

FiraCode - [Source](https://github.com/tonsky/FiraCode) - [OFL-1.1 license](https://github.com/tonsky/FiraCode?tab=OFL-1.1-1-ov-file)

raylib - [Source](https://github.com/raysan5/raylib) - [Zlib license](https://github.com/raysan5/raylib?tab=Zlib-1-ov-file)

Zig - [Source](https://github.com/ziglang/zig) - [MIT license](https://github.com/ziglang/zig?tab=MIT-1-ov-file)
