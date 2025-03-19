const std: type = @import("std");
const rl: type = @import("raylib");
const rg: type = @import("raygui");
const fw: type = @import("GuiFloatWindow.zig");
const sb: type = @import("GuiScrollbar.zig");
const Consts: type = @import("Consts.zig");

const styles: [12][*:0]const u8 = .{
    "styles/style_amber.rgs",
    "styles/style_ashes.rgs",
    "styles/style_bluish.rgs",
    "styles/style_candy.rgs",
    "styles/style_cherry.rgs",
    "styles/style_cyber.rgs",
    "styles/style_dark.rgs",
    "styles/style_enefete.rgs",
    "styles/style_jungle.rgs",
    "styles/style_lavanda.rgs",
    "styles/style_sunny.rgs",
    "styles/style_terminal.rgs",
};

var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var gpa_allocator: std.mem.Allocator = undefined;

var font: rl.Font = undefined;

var prevStyleIndex: i32 = 8;
var styleIndex: i32 = 8;
var styleDropdownActive: bool = false;

var backgroundColor: rl.Color = undefined;
var lineColor: rl.Color = undefined;
var selectedColor: rl.Color = undefined;

var prevScreenWidth: i32 = undefined;
var prevScreenHeight: i32 = undefined;

var tilesWindow: *fw.GuiFloatWindow = undefined;
var clipboardWindow: *fw.GuiFloatWindow = undefined;
var editorWindow: *fw.GuiFloatWindow = undefined;
var palleteWindow: *fw.GuiFloatWindow = undefined;
var selectorWindow: *fw.GuiFloatWindow = undefined;

var windows: std.ArrayList(*fw.GuiFloatWindow) = undefined;
var windowsHandled: bool = false;

var tilesGrid: bool = true;
var clipboardGrid: bool = true;
var editorGrid: bool = true;

var prevTilesPixelSize: i32 = Consts.TILES_PIXEL_SIZE_DEFAULT;
var tilesPixelSize: i32 = Consts.TILES_PIXEL_SIZE_DEFAULT;

var prevClipboardPixelSize: i32 = Consts.CLIPBOARD_PIXEL_SIZE_DEFAULT;
var clipboardPixelSize: i32 = Consts.CLIPBOARD_PIXEL_SIZE_DEFAULT;

var prevEditorPixelSize: i32 = Consts.EDITOR_PIXEL_SIZE_DEFAULT;
var editorPixelSize: i32 = Consts.EDITOR_PIXEL_SIZE_DEFAULT;

var prevEditorTilesSquareSize: i32 = Consts.EDITOR_SQUARE_SIZE_DEFAULT;
var editorTilesSquareSize: i32 = Consts.EDITOR_SQUARE_SIZE_DEFAULT;

var prevTilesOffset: i32 = 0;
var tilesOffset: i32 = 0;

var activeTile: i32 = 0;

var bitsPerPixel: u8 = 1;
var bytesPerTile: u8 = 8;

var pallete: [256]rl.Color = .{rl.Color.black} ** 256;
var palleteCount: usize = 2;
var palleteRows: i32 = 2;
var palleteColumns: i32 = 1;
var palleteEditing: bool = false;

var romFileName: ?[:0]u8 = null;
var romData: []u8 = undefined;
var romAddress: i32 = undefined;
var romOffset: i32 = undefined;

var tilesData: [8 * 8 * Consts.TILES_TILES_PER_LINE * Consts.TILES_LINES]u8 = .{0} ** (8 * 8 * Consts.TILES_TILES_PER_LINE * Consts.TILES_LINES);
var clipboardData: [8 * 8 * Consts.CLIPBOARD_TILES_PER_LINE * Consts.CLIPBOARD_LINES]u8 = .{0} ** (8 * 8 * Consts.CLIPBOARD_TILES_PER_LINE * Consts.CLIPBOARD_LINES);
var editorData: [8 * 8 * Consts.EDITOR_SQUARE_SIZE_MAX * Consts.EDITOR_SQUARE_SIZE_MAX]u8 = .{0} ** (8 * 8 * Consts.EDITOR_SQUARE_SIZE_MAX * Consts.EDITOR_SQUARE_SIZE_MAX);

var tilesLines: i32 = 0;
var tilesLastLine: i32 = 0;
var tilesCurrentLine: i32 = 0;

var prevPixelMode: i32 = 0;
var pixelMode: i32 = 0;
var pixelModeDropdownActive: bool = false;

var editorForegroundColorIndex: u8 = 1;
var editorBackgroundColorIndex: u8 = 0;

var colorPickerColor: rl.Color = rl.Color.black;

var mousePosition: rl.Vector2 = rl.Vector2.init(0, 0);

pub fn loadStyle() void {
    rg.guiLoadStyle(styles[@as(usize, @intCast(styleIndex))]);

    rg.guiSetFont(font);

    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiDefaultProperty.text_size,
        12,
    );

    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiDefaultProperty.text_line_spacing,
        18,
    );

    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiControlProperty.text_alignment,
        @intFromEnum(rg.GuiTextAlignment.text_align_center),
    );

    backgroundColor = rl.Color.fromInt(@as(u32, @bitCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.background_color))));

    lineColor = rl.Color.fromInt(@as(u32, @bitCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.line_color))));

    selectedColor = rl.colorAlpha(
        rl.Color.fromInt(
            @as(u32, @bitCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.base_color_focused))),
        ),
        0.5,
    );
}

pub fn isForegroundWindow(window: *fw.GuiFloatWindow) bool {
    if (windows.items.len == 0) {
        return false;
    }

    return windows.items[windows.items.len - 1] == window;
}

pub fn isDropdownActive() bool {
    return styleDropdownActive or pixelModeDropdownActive;
}

pub fn ensureWindowVisibility(window: *fw.GuiFloatWindow) void {
    const left: f32 = window.windowRect.x;
    const top: f32 = window.windowRect.y;
    const right: f32 = window.windowRect.x + window.windowRect.width;
    const limitTop: f32 = @as(f32, @floatFromInt(Consts.TOOLBAR_HEIGHT + Consts.STATUSBAR_HEIGHT));
    const limitLeft: f32 = @as(f32, @floatFromInt(fw.GuiFloatWindow.HEADER_HEIGHT));
    const limitRight: f32 = @as(f32, @floatFromInt(rl.getScreenWidth() - fw.GuiFloatWindow.HEADER_HEIGHT));
    const limitBottom: f32 = @as(f32, @floatFromInt(rl.getScreenHeight() - fw.GuiFloatWindow.HEADER_HEIGHT));

    var delta: rl.Vector2 = rl.Vector2.init(0, 0);

    if (right < limitLeft) {
        delta.x = limitLeft - right;
    } else if (left > limitRight) {
        delta.x = limitRight - left;
    }

    if (top < limitTop) {
        delta.y = limitTop - top;
    } else if (top > limitBottom) {
        delta.y = limitBottom - top;
    }

    if (delta.x == 0 and delta.y == 0) {
        return;
    }

    window.moveBy(delta);
}

pub fn ensureWindowsVisibility() void {
    for (windows.items) |window| {
        ensureWindowVisibility(window);
    }
}

pub fn getWindowUnderMouse() ?*fw.GuiFloatWindow {
    if (windows.items.len == 0) {
        return null;
    }

    var i: usize = windows.items.len - 1;

    while (i >= 0) {
        const window: *fw.GuiFloatWindow = windows.items[i];

        if (!rl.checkCollisionPointRec(mousePosition, window.windowRect)) {
            i -= 1;

            continue;
        }

        return window;
    }

    return null;
}

pub fn resetTilesData() void {
    for (0..tilesData.len) |i| {
        tilesData[i] = 0;
    }
}

pub fn resetClipboardData() void {
    for (0..clipboardData.len) |i| {
        clipboardData[i] = 0;
    }
}

pub fn resetEditorData() void {
    for (0..editorData.len) |i| {
        editorData[i] = 0;
    }
}

pub fn resetPallete() void {
    for (0..pallete.len) |i| {
        pallete[i] = rl.Color.black;
    }
}

pub fn resetAll() void {
    resetTilesData();
    resetClipboardData();
    resetEditorData();
    resetPallete();
}

pub fn initializePallete() void {
    for (0..pallete.len) |i| {
        const value: u8 = @as(u8, @intCast(i));

        pallete[i] = rl.Color.init(value, value, value, 255);
    }

    palleteCount = 256;
    palleteRows = 16;
    palleteColumns = 16;

    editorForegroundColorIndex = 255;
    editorBackgroundColorIndex = 0;
}

pub fn loadPixelModePallete() anyerror!void {
    resetPallete();

    const mode: Consts.PixelMode = @enumFromInt(pixelMode);

    switch (mode) {
        .one_bpp => {
            pallete[0] = rl.Color.black;
            pallete[1] = rl.Color.white;

            palleteCount = 2;
            palleteRows = 2;
            palleteColumns = 1;

            bitsPerPixel = 1;
        },
        .two_bpp_gb_gbc => {
            pallete[0] = rl.Color.black;
            pallete[1] = rl.Color.gray;
            pallete[2] = rl.Color.light_gray;
            pallete[3] = rl.Color.white;

            palleteCount = 4;
            palleteRows = 2;
            palleteColumns = 2;

            bitsPerPixel = 2;
        },
        .eight_bpp_snes => {
            initializePallete();
        },
        else => {},
    }

    bytesPerTile = 8 * bitsPerPixel;

    tilesLines = try std.math.divCeil(i32, @as(i32, @intCast(romData.len)), @as(i32, @intCast(bytesPerTile * Consts.TILES_TILES_PER_LINE)));
    tilesLastLine = @max(0, tilesLines - Consts.TILES_LINES);

    editorForegroundColorIndex = @as(u8, @intCast(palleteCount - 1));
    editorBackgroundColorIndex = 0;

    for (0..clipboardData.len) |i| {
        if (clipboardData[i] < palleteCount) {
            continue;
        }

        clipboardData[i] = @as(u8, @intCast(palleteCount - 1));
    }

    for (0..editorData.len) |i| {
        if (editorData[i] < palleteCount) {
            continue;
        }

        editorData[i] = @as(u8, @intCast(palleteCount - 1));
    }
}

pub fn processROMData() void {
    if (romData.len == 0) {
        return;
    }

    for (0..Consts.TILES_TILES_PER_LINE * Consts.TILES_LINES) |tileIndex| {
        const dataIndex: i32 = tilesCurrentLine * Consts.TILES_TILES_PER_LINE * bytesPerTile + @as(i32, @intCast(tileIndex)) * bytesPerTile + romOffset;

        for (0..8) |y| {
            for (0..8) |x| {
                var colorIndex: u8 = 0;

                processColor: {
                    switch (@as(Consts.PixelMode, @enumFromInt(pixelMode))) {
                        .two_bpp_gb_gbc => {
                            const byteIndex: usize = @as(usize, @intCast(dataIndex)) + y * @as(usize, @intCast(bitsPerPixel));

                            if (byteIndex >= romData.len - 1) {
                                break :processColor;
                            }

                            const byteOne: u8 = romData[byteIndex];
                            const byteTwo: u8 = romData[byteIndex + 1];
                            const bit: u8 = 7 - @as(u8, @intCast(x));
                            const bitValue: u8 = @as(u8, @intCast(1)) << @as(u3, @intCast(bit));

                            if ((byteOne & bitValue) != 0) {
                                colorIndex += 1;
                            }

                            if ((byteTwo & bitValue) != 0) {
                                colorIndex += 2;
                            }
                        },
                        else => {},
                    }
                }

                tilesData[tileIndex * 8 * 8 + y * 8 + x] = colorIndex;
            }
        }
    }
}

pub fn loadPixelMode() anyerror!void {
    try loadPixelModePallete();
    processROMData();
}

pub fn setROMAddress(address: i32) void {
    romAddress = address;

    processROMData();
}

pub fn setROMOffset(offset: i32) void {
    const clampedOffset: i32 = std.math.clamp(offset, 0, 16);

    if (clampedOffset == romOffset) {
        return;
    }

    prevTilesOffset = clampedOffset;
    tilesOffset = clampedOffset;

    romOffset = clampedOffset;

    processROMData();
}

pub fn setTilesCurrentLine(lineNumber: i32, updateScrollbar: bool) void {
    const clampedLineNumber: i32 = std.math.clamp(lineNumber, 0, tilesLastLine);

    if (clampedLineNumber == tilesCurrentLine) {
        return;
    }

    tilesCurrentLine = clampedLineNumber;

    romAddress = tilesCurrentLine * Consts.TILES_TILES_PER_LINE * bytesPerTile;

    if (updateScrollbar) {
        tilesWindow.scrollbarVertical.?.value = @as(f32, @floatFromInt(tilesCurrentLine)) / @as(f32, @floatFromInt(tilesLastLine));
    }

    processROMData();
}

pub fn loadROM(fileName: [*c]u8) anyerror!void {
    if (romData.len > 0) {
        rl.unloadFileData(romData);
    }

    if (romFileName != null) {
        gpa_allocator.free(romFileName.?);
    }

    romFileName = try gpa_allocator.dupeZ(u8, std.mem.span(fileName));

    romData = try rl.loadFileData(fileName);

    romAddress = 0;
    romOffset = 0;

    prevTilesOffset = 0;
    tilesOffset = 0;

    resetAll();

    if (rl.isFileExtension(fileName, ".gb") or rl.isFileExtension(fileName, ".gbc")) {
        pixelMode = @intFromEnum(Consts.PixelMode.two_bpp_gb_gbc);
    } else {
        pixelMode = @intFromEnum(Consts.PixelMode.one_bpp);
    }

    prevPixelMode = pixelMode;

    try loadPixelMode();
}

pub fn saveROM() void {
    if (romData.len == 0) {
        return;
    }

    if (romFileName) |fileName| {
        _ = rl.saveFileData(fileName, romData);
    }
}

pub fn handleInputs() void {
    if (rl.isKeyPressed(.equal) or rl.isKeyPressedRepeat(.equal)) {
        setROMOffset(romOffset + 1);
    } else if (rl.isKeyPressed(.minus) or rl.isKeyPressedRepeat(.minus)) {
        setROMOffset(romOffset - 1);
    } else if (rl.isKeyPressed(.up) or rl.isKeyPressedRepeat(.up)) {
        setTilesCurrentLine(tilesCurrentLine - 1, true);
    } else if (rl.isKeyPressed(.down) or rl.isKeyPressedRepeat(.down)) {
        setTilesCurrentLine(tilesCurrentLine + 1, true);
    } else if (rl.isKeyPressed(.page_up) or rl.isKeyPressedRepeat(.page_up)) {
        setTilesCurrentLine(tilesCurrentLine - Consts.TILES_LINES, true);
    } else if (rl.isKeyPressed(.page_down) or rl.isKeyPressedRepeat(.page_down)) {
        setTilesCurrentLine(tilesCurrentLine + Consts.TILES_LINES, true);
    } else if (rl.isKeyDown(.left_control)) {
        if (rl.isKeyPressed(.home) or rl.isKeyPressedRepeat(.home)) {
            setTilesCurrentLine(0, true);
        } else if (rl.isKeyPressed(.end) or rl.isKeyPressedRepeat(.end)) {
            setTilesCurrentLine(tilesLastLine, true);
        }
    }

    const wheel: f32 = rl.getMouseWheelMove();

    if (wheel != 0) {
        setTilesCurrentLine(tilesCurrentLine - @as(i32, @intFromFloat(wheel)) * Consts.WHEEL_SCROLL_LINES, true);
    }
}

pub fn tilesWindowEventHandler(event: fw.GuiFloatWindowEvent) void {
    var mouseHandled: bool = false;

    var tilesTileX: i32 = undefined;
    var tilesTileY: i32 = undefined;
    var tilesTileIndex: usize = undefined;

    switch (event) {
        .left_click_start,
        .left_click_moved,
        .right_click_start,
        .right_click_moved,
        => |arguments| {
            mouseHandled = true;

            tilesTileX = @divFloor(@as(i32, @intFromFloat(arguments.mousePosition.x)), 8 * tilesPixelSize);
            tilesTileY = @divFloor(@as(i32, @intFromFloat(arguments.mousePosition.y)), 8 * tilesPixelSize);
            tilesTileIndex = @as(usize, @intCast(tilesTileY * Consts.TILES_TILES_PER_LINE + tilesTileX)) * 8 * 8;
        },
        .scroll_vertical_start,
        .scroll_vertical_moved,
        => |arguments| {
            setTilesCurrentLine(@as(i32, @intFromFloat(arguments.scrollbar.value * @as(f32, @floatFromInt(tilesLastLine)))), false);
        },
        else => {},
    }

    if (!mouseHandled) {
        return;
    }

    const editorTileIndex: usize = @as(usize, @intCast(activeTile * 8 * 8));

    switch (event) {
        .left_click_start, .left_click_moved => {
            for (0..8 * 8) |i| {
                editorData[editorTileIndex + i] = tilesData[tilesTileIndex + i];
            }
        },
        .right_click_start, .right_click_moved => {
            for (0..8 * 8) |i| {
                tilesData[tilesTileIndex + i] = editorData[editorTileIndex + i];
            }
        },
        else => {},
    }
}

pub fn clipboardWindowEventHandler(event: fw.GuiFloatWindowEvent) void {
    var handled: bool = false;

    var clipboardTileX: i32 = undefined;
    var clipboardTileY: i32 = undefined;
    var clipboardTileIndex: usize = undefined;

    switch (event) {
        .left_click_start,
        .left_click_moved,
        .right_click_start,
        .right_click_moved,
        => |arguments| {
            handled = true;

            clipboardTileX = @divFloor(@as(i32, @intFromFloat(arguments.mousePosition.x)), 8 * clipboardPixelSize);
            clipboardTileY = @divFloor(@as(i32, @intFromFloat(arguments.mousePosition.y)), 8 * clipboardPixelSize);
            clipboardTileIndex = @as(usize, @intCast(clipboardTileY * Consts.CLIPBOARD_TILES_PER_LINE + clipboardTileX)) * 8 * 8;
        },
        else => {},
    }

    if (!handled) {
        return;
    }

    const editorTileIndex: usize = @as(usize, @intCast(activeTile * 8 * 8));

    switch (event) {
        .left_click_start, .left_click_moved => {
            for (0..8 * 8) |i| {
                editorData[editorTileIndex + i] = clipboardData[clipboardTileIndex + i];
            }
        },
        .right_click_start, .right_click_moved => {
            for (0..8 * 8) |i| {
                clipboardData[clipboardTileIndex + i] = editorData[editorTileIndex + i];
            }
        },
        else => {},
    }
}

pub fn editorWindowEventHandler(event: fw.GuiFloatWindowEvent) void {
    var drawing: bool = false;
    var colorIndex: u8 = 0;
    var pixelIndex: usize = 0;

    switch (event) {
        .left_click_start,
        .left_click_moved,
        .right_click_start,
        .right_click_moved,
        => |arguments| {
            const tileX: i32 = @divFloor(@as(i32, @intFromFloat(arguments.mousePosition.x)), 8 * editorPixelSize);
            const tileY: i32 = @divFloor(@as(i32, @intFromFloat(arguments.mousePosition.y)), 8 * editorPixelSize);
            const leftoverX: i32 = @mod(@as(i32, @intFromFloat(arguments.mousePosition.x)), 8 * editorPixelSize);
            const leftoverY: i32 = @mod(@as(i32, @intFromFloat(arguments.mousePosition.y)), 8 * editorPixelSize);
            const pixelX: i32 = @divFloor(leftoverX, editorPixelSize);
            const pixelY: i32 = @divFloor(leftoverY, editorPixelSize);
            const tile: i32 = tileY * 4 + tileX;
            const pixel: i32 = pixelY * 8 + pixelX;

            drawing = true;
            pixelIndex = @as(usize, @intCast(tile * 8 * 8 + pixel));
        },
        else => {},
    }

    switch (event) {
        .left_click_start, .left_click_moved => {
            colorIndex = editorForegroundColorIndex;
        },
        .right_click_start, .right_click_moved => {
            colorIndex = editorBackgroundColorIndex;
        },
        else => {},
    }

    if (drawing) {
        editorData[pixelIndex] = colorIndex;
    }
}

pub fn palleteWindowEventHandler(event: fw.GuiFloatWindowEvent) void {
    const colorsRect: rl.Rectangle = .{
        .x = palleteWindow.bodyRect.x,
        .y = palleteWindow.bodyRect.y,
        .width = Consts.PALLETE_AREA_SIZE,
        .height = Consts.PALLETE_AREA_SIZE,
    };

    var selectingColor: bool = false;
    var selectingBackground: bool = false;

    switch (event) {
        .left_click_start, .left_click_moved => {
            if (rl.checkCollisionPointRec(mousePosition, colorsRect)) {
                selectingColor = true;
                selectingBackground = false;
            }
        },
        .right_click_start, .right_click_moved => {
            if (rl.checkCollisionPointRec(mousePosition, colorsRect)) {
                selectingColor = true;
                selectingBackground = true;
            }
        },
        else => {},
    }

    if (selectingColor) {
        const colorWidth: i32 = @divFloor(Consts.PALLETE_AREA_SIZE, palleteColumns);
        const colorHeight: i32 = @divFloor(Consts.PALLETE_AREA_SIZE, palleteRows);
        const localX: i32 = @as(i32, @intFromFloat(mousePosition.x - palleteWindow.bodyRect.x));
        const localY: i32 = @as(i32, @intFromFloat(mousePosition.y - palleteWindow.bodyRect.y));
        const colorX: i32 = @divFloor(localX, colorWidth);
        const colorY: i32 = @divFloor(localY, colorHeight);
        const colorIndex: u8 = @as(u8, @intCast(colorY * palleteColumns + colorX));

        if (selectingBackground) {
            editorBackgroundColorIndex = colorIndex;
        } else {
            editorForegroundColorIndex = colorIndex;
        }

        colorPickerColor = pallete[colorIndex];
    }
}

pub fn handleAndDrawTilesWindow() anyerror!void {
    for (0..tilesData.len) |i| {
        const tile: i32 = @divFloor(@as(i32, @intCast(i)), 8 * 8);
        const leftover: i32 = @mod(@as(i32, @intCast(i)), 8 * 8);
        const tileX: i32 = @mod(tile, Consts.TILES_TILES_PER_LINE);
        const tileY: i32 = @divFloor(tile, Consts.TILES_TILES_PER_LINE);
        const pixelX: i32 = @mod(leftover, 8);
        const pixelY: i32 = @divFloor(leftover, 8);
        const color: rl.Color = pallete[tilesData[i]];

        rl.drawRectangle(
            @as(i32, @intFromFloat(tilesWindow.bodyRect.x)) + tileX * 8 * tilesPixelSize + pixelX * tilesPixelSize,
            @as(i32, @intFromFloat(tilesWindow.bodyRect.y)) + tileY * 8 * tilesPixelSize + pixelY * tilesPixelSize,
            tilesPixelSize,
            tilesPixelSize,
            color,
        );
    }

    if (tilesGrid) {
        var mouseCell: rl.Vector2 = undefined;

        _ = rg.guiGrid(tilesWindow.bodyRect, "", @as(f32, @floatFromInt(8 * tilesPixelSize)), 1, &mouseCell);
    }

    if (rl.checkCollisionPointRec(mousePosition, tilesWindow.bodyRect) and getWindowUnderMouse() == tilesWindow) {
        const localX: f32 = mousePosition.x - tilesWindow.bodyRect.x;
        const localY: f32 = mousePosition.y - tilesWindow.bodyRect.y;
        const cellX: f32 = @divFloor(localX, 8 * @as(f32, @floatFromInt(tilesPixelSize)));
        const cellY: f32 = @divFloor(localY, 8 * @as(f32, @floatFromInt(tilesPixelSize)));
        const rectX: i32 = @as(i32, @intFromFloat(tilesWindow.bodyRect.x)) + @as(i32, @intFromFloat(cellX)) * 8 * tilesPixelSize;
        const rectY: i32 = @as(i32, @intFromFloat(tilesWindow.bodyRect.y)) + @as(i32, @intFromFloat(cellY)) * 8 * tilesPixelSize;
        const rectSize: i32 = 8 * tilesPixelSize;

        rl.drawRectangle(rectX, rectY, rectSize, rectSize, selectedColor);

        rl.drawRectangleLines(rectX, rectY, rectSize, rectSize, lineColor);
    }
}

pub fn handleAndDrawClipboardWindow() anyerror!void {
    for (0..clipboardData.len) |i| {
        const tile: i32 = @divFloor(@as(i32, @intCast(i)), 8 * 8);
        const leftover: i32 = @mod(@as(i32, @intCast(i)), 8 * 8);
        const tileX: i32 = @mod(tile, Consts.CLIPBOARD_TILES_PER_LINE);
        const tileY: i32 = @divFloor(tile, Consts.CLIPBOARD_TILES_PER_LINE);
        const pixelX: i32 = @mod(leftover, 8);
        const pixelY: i32 = @divFloor(leftover, 8);
        const color: rl.Color = pallete[clipboardData[i]];

        rl.drawRectangle(
            @as(i32, @intFromFloat(clipboardWindow.bodyRect.x)) + tileX * 8 * clipboardPixelSize + pixelX * clipboardPixelSize,
            @as(i32, @intFromFloat(clipboardWindow.bodyRect.y)) + tileY * 8 * clipboardPixelSize + pixelY * clipboardPixelSize,
            clipboardPixelSize,
            clipboardPixelSize,
            color,
        );
    }

    if (clipboardGrid) {
        var mouseCell: rl.Vector2 = undefined;

        _ = rg.guiGrid(clipboardWindow.bodyRect, "", @as(f32, @floatFromInt(8 * clipboardPixelSize)), 1, &mouseCell);
    }

    if (rl.checkCollisionPointRec(mousePosition, clipboardWindow.bodyRect) and getWindowUnderMouse() == clipboardWindow) {
        const localX: f32 = mousePosition.x - clipboardWindow.bodyRect.x;
        const localY: f32 = mousePosition.y - clipboardWindow.bodyRect.y;
        const cellX: f32 = @divFloor(localX, 8 * @as(f32, @floatFromInt(clipboardPixelSize)));
        const cellY: f32 = @divFloor(localY, 8 * @as(f32, @floatFromInt(clipboardPixelSize)));
        const rectX: i32 = @as(i32, @intFromFloat(clipboardWindow.bodyRect.x)) + @as(i32, @intFromFloat(cellX)) * 8 * clipboardPixelSize;
        const rectY: i32 = @as(i32, @intFromFloat(clipboardWindow.bodyRect.y)) + @as(i32, @intFromFloat(cellY)) * 8 * clipboardPixelSize;
        const rectSize: i32 = 8 * clipboardPixelSize;

        rl.drawRectangle(rectX, rectY, rectSize, rectSize, selectedColor);

        rl.drawRectangleLines(rectX, rectY, rectSize, rectSize, lineColor);
    }
}

pub fn handleAndDrawEditorWindow() anyerror!void {
    for (0..editorData.len) |i| {
        const tile: i32 = @divFloor(@as(i32, @intCast(i)), 8 * 8);
        const leftover: i32 = @mod(@as(i32, @intCast(i)), 8 * 8);
        const tileX: i32 = @mod(tile, 4);
        const tileY: i32 = @divFloor(tile, 4);
        const pixelX: i32 = @mod(leftover, 8);
        const pixelY: i32 = @divFloor(leftover, 8);
        const color: rl.Color = pallete[editorData[i]];

        if (tileX >= editorTilesSquareSize or tileY >= editorTilesSquareSize) {
            continue;
        }

        rl.drawRectangle(
            @as(i32, @intFromFloat(editorWindow.bodyRect.x)) + tileX * 8 * editorPixelSize + pixelX * editorPixelSize,
            @as(i32, @intFromFloat(editorWindow.bodyRect.y)) + tileY * 8 * editorPixelSize + pixelY * editorPixelSize,
            editorPixelSize,
            editorPixelSize,
            color,
        );
    }

    if (editorGrid) {
        var mouseCell: rl.Vector2 = undefined;

        _ = rg.guiGrid(editorWindow.bodyRect, "", @as(f32, @floatFromInt(editorPixelSize * 8)), 8, &mouseCell);
    }

    if (rl.checkCollisionPointRec(mousePosition, editorWindow.bodyRect) and getWindowUnderMouse() == editorWindow) {
        const localX: f32 = mousePosition.x - editorWindow.bodyRect.x;
        const localY: f32 = mousePosition.y - editorWindow.bodyRect.y;
        const cellX: f32 = @divFloor(localX, @as(f32, @floatFromInt(editorPixelSize)));
        const cellY: f32 = @divFloor(localY, @as(f32, @floatFromInt(editorPixelSize)));
        const rectX: i32 = @as(i32, @intFromFloat(editorWindow.bodyRect.x)) + @as(i32, @intFromFloat(cellX)) * editorPixelSize;
        const rectY: i32 = @as(i32, @intFromFloat(editorWindow.bodyRect.y)) + @as(i32, @intFromFloat(cellY)) * editorPixelSize;

        rl.drawRectangle(rectX, rectY, editorPixelSize, editorPixelSize, selectedColor);

        rl.drawRectangleLines(rectX, rectY, editorPixelSize, editorPixelSize, lineColor);
    }

    if (rl.checkCollisionPointRec(mousePosition, selectorWindow.bodyRect) and getWindowUnderMouse() == selectorWindow) {
        const oldTextSize: i32 = rg.guiGetStyle(rg.GuiControl.default, rg.GuiDefaultProperty.text_size);

        defer rg.guiSetStyle(rg.GuiControl.default, rg.GuiDefaultProperty.text_size, oldTextSize);

        rg.guiSetStyle(rg.GuiControl.default, rg.GuiDefaultProperty.text_size, @as(i32, @intFromFloat(@as(f32, @floatFromInt(editorPixelSize)) * 2.666667)));

        var buffer: [3]u8 = .{0} ** 3;

        const localX: f32 = mousePosition.x - selectorWindow.bodyRect.x;
        const localY: f32 = mousePosition.y - selectorWindow.bodyRect.y;
        const mouseOverCellX: i32 = @as(i32, @intFromFloat(@divFloor(localX, @as(f32, @floatFromInt(Consts.SELECTOR_BUTTON_SIZE)))));
        const mouseOverCellY: i32 = @as(i32, @intFromFloat(@divFloor(localY, @as(f32, @floatFromInt(Consts.SELECTOR_BUTTON_SIZE)))));
        const mouseOverCellIndex: i32 = mouseOverCellY * Consts.EDITOR_SQUARE_SIZE_MAX + mouseOverCellX;

        for (0..Consts.EDITOR_SQUARE_SIZE_MAX * Consts.EDITOR_SQUARE_SIZE_MAX) |i| {
            const x: i32 = @mod(@as(i32, @intCast(i)), Consts.EDITOR_SQUARE_SIZE_MAX);
            const y: i32 = @divFloor(@as(i32, @intCast(i)), Consts.EDITOR_SQUARE_SIZE_MAX);

            if (x >= editorTilesSquareSize or y >= editorTilesSquareSize) {
                continue;
            }

            const cellRect: rl.Rectangle = .{
                .x = editorWindow.bodyRect.x + @as(f32, @floatFromInt(x * 8 * editorPixelSize)),
                .y = editorWindow.bodyRect.y + @as(f32, @floatFromInt(y * 8 * editorPixelSize)),
                .width = @as(f32, @floatFromInt(8 * editorPixelSize)),
                .height = @as(f32, @floatFromInt(8 * editorPixelSize)),
            };

            if (i == mouseOverCellIndex) {
                rl.drawRectangleRec(cellRect, selectedColor);
            }

            if (i == activeTile) {
                rl.drawRectangleLinesEx(
                    cellRect,
                    @as(f32, @floatFromInt(2 * fw.GuiFloatWindow.BORDER_WIDTH)),
                    lineColor,
                );
            }

            const text: [:0]u8 = try std.fmt.bufPrintZ(&buffer, "{d}", .{i});

            _ = rg.guiLabel(cellRect, text);
        }
    }
}

pub fn handleAndDrawSelectorWindow() anyerror!void {
    const oldState = rg.guiGetState();

    var buffer: [3]u8 = .{0} ** 3;

    for (0..Consts.EDITOR_SQUARE_SIZE_MAX * Consts.EDITOR_SQUARE_SIZE_MAX) |i| {
        const x: i32 = @mod(@as(i32, @intCast(i)), Consts.EDITOR_SQUARE_SIZE_MAX);
        const y: i32 = @divFloor(@as(i32, @intCast(i)), Consts.EDITOR_SQUARE_SIZE_MAX);
        const text: [:0]u8 = try std.fmt.bufPrintZ(&buffer, "{d}", .{i});

        if (x >= editorTilesSquareSize or y >= editorTilesSquareSize) {
            rg.guiSetState(@intFromEnum(rg.GuiState.state_disabled));
        } else {
            rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));

            if (i == activeTile) {
                rg.guiSetState(@intFromEnum(rg.GuiState.state_pressed));
            } else {
                rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));
            }
        }

        const ret: i32 = rg.guiButton(
            .{
                .x = selectorWindow.bodyRect.x + @as(f32, @floatFromInt(x * Consts.SELECTOR_BUTTON_SIZE)),
                .y = selectorWindow.bodyRect.y + @as(f32, @floatFromInt(y * Consts.SELECTOR_BUTTON_SIZE)),
                .width = Consts.SELECTOR_BUTTON_SIZE,
                .height = Consts.SELECTOR_BUTTON_SIZE,
            },
            text,
        );

        if (ret == 1 and isForegroundWindow(selectorWindow)) {
            activeTile = @as(i32, @intCast(i));
        }
    }

    rg.guiSetState(oldState);
}

pub fn handleAndDrawPalleteWindow() anyerror!void {
    const bodyX: i32 = @as(i32, @intFromFloat(palleteWindow.bodyRect.x));
    const bodyY: i32 = @as(i32, @intFromFloat(palleteWindow.bodyRect.y));
    const colorWidth: i32 = @divFloor(Consts.PALLETE_AREA_SIZE, palleteColumns);
    const colorHeight: i32 = @divFloor(Consts.PALLETE_AREA_SIZE, palleteRows);

    for (0..palleteCount) |i| {
        const x: i32 = @mod(@as(i32, @intCast(i)), palleteColumns);
        const y: i32 = @divFloor(@as(i32, @intCast(i)), palleteColumns);

        rl.drawRectangle(
            bodyX + x * colorWidth,
            bodyY + y * colorHeight,
            colorWidth,
            colorHeight,
            pallete[i],
        );
    }

    const colorsRect: rl.Rectangle = .{
        .x = palleteWindow.bodyRect.x,
        .y = palleteWindow.bodyRect.y,
        .width = Consts.PALLETE_AREA_SIZE,
        .height = Consts.PALLETE_AREA_SIZE,
    };

    var colorUnderMouseIndex: ?u8 = null;

    if (rl.checkCollisionPointRec(mousePosition, colorsRect) and getWindowUnderMouse() == palleteWindow) {
        const localX: i32 = @as(i32, @intFromFloat(mousePosition.x)) - bodyX;
        const localY: i32 = @as(i32, @intFromFloat(mousePosition.y)) - bodyY;
        const colorX: i32 = @divFloor(localX, colorWidth);
        const colorY: i32 = @divFloor(localY, colorHeight);

        colorUnderMouseIndex = @as(u8, @intCast(colorY * palleteColumns + colorX));

        rl.drawRectangle(bodyX + colorX * colorWidth, bodyY + colorY * colorHeight, colorWidth, colorHeight, selectedColor);

        rl.drawRectangleLines(bodyX + colorX * colorWidth, bodyY + colorY * colorHeight, colorWidth, colorHeight, lineColor);
    }

    rl.drawRectangle(bodyX + 32, bodyY + Consts.PALLETE_AREA_SIZE + 32, 48, 48, pallete[editorBackgroundColorIndex]);
    rl.drawRectangleLines(bodyX + 32, bodyY + Consts.PALLETE_AREA_SIZE + 32, 48, 48, lineColor);

    rl.drawRectangle(bodyX + 8, bodyY + Consts.PALLETE_AREA_SIZE + 8, 48, 48, pallete[editorForegroundColorIndex]);
    rl.drawRectangleLines(bodyX + 8, bodyY + Consts.PALLETE_AREA_SIZE + 8, 48, 48, lineColor);

    const swapButtonResult: i32 = rg.guiButton(.{
        .x = @as(f32, @floatFromInt(bodyX + 7)),
        .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 57)),
        .width = Consts.TOOLBAR_ITEM_HEIGHT,
        .height = Consts.TOOLBAR_ITEM_HEIGHT,
    }, "#77#");

    if (swapButtonResult != 0) {
        const tempColorIndex: u8 = editorForegroundColorIndex;

        editorForegroundColorIndex = editorBackgroundColorIndex;
        editorBackgroundColorIndex = tempColorIndex;
    }

    _ = rg.guiToggle(.{
        .x = @as(f32, @floatFromInt(bodyX + 56)),
        .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 8)),
        .width = Consts.TOOLBAR_ITEM_HEIGHT,
        .height = Consts.TOOLBAR_ITEM_HEIGHT,
    }, "#142#", &palleteEditing);

    if (palleteEditing) {
        const colorPickerRect: rl.Rectangle = .{
            .x = @as(f32, @floatFromInt(bodyX + 88)),
            .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 8)),
            .width = Consts.PALLETE_AREA_SIZE - 120,
            .height = 48,
        };

        _ = rg.guiColorPicker(colorPickerRect, "", &colorPickerColor);

        const setButtonsWidth: i32 = @divFloor(Consts.PALLETE_AREA_SIZE - 96, 2);

        const setForegroundResult: i32 = rg.guiButton(.{
            .x = @as(f32, @floatFromInt(bodyX + 88)),
            .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 56)),
            .width = setButtonsWidth,
            .height = Consts.TOOLBAR_ITEM_HEIGHT,
        }, "Set FG");

        if (setForegroundResult != 0) {
            pallete[editorForegroundColorIndex] = colorPickerColor;
        }

        const setBackgroundResult: i32 = rg.guiButton(.{
            .x = @as(f32, @floatFromInt(bodyX + 88 + setButtonsWidth)),
            .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 56)),
            .width = setButtonsWidth,
            .height = Consts.TOOLBAR_ITEM_HEIGHT,
        }, "Set BG");

        if (setBackgroundResult != 0) {
            pallete[editorBackgroundColorIndex] = colorPickerColor;
        }
    } else {
        var buffer: [32]u8 = .{0} ** 32;
        var text: [:0]u8 = undefined;

        if (colorUnderMouseIndex) |colorIndex| {
            const color: rl.Color = pallete[colorIndex];

            text = try std.fmt.bufPrintZ(&buffer, "R: {d}\nG: {d}\nB: {d}\nIndex: {d}", .{ color.r, color.g, color.b, colorIndex });
        } else {
            text = try std.fmt.bufPrintZ(&buffer, "R: -\nG: -\nB: -\nIndex: -", .{});
        }

        rg.guiSetStyle(
            rg.GuiControl.default,
            rg.GuiControlProperty.text_alignment,
            @intFromEnum(rg.GuiTextAlignment.text_align_right),
        );

        _ = rg.guiLabel(.{
            .x = @as(f32, @floatFromInt(bodyX + 88)),
            .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 21)),
            .width = Consts.PALLETE_AREA_SIZE - 96,
            .height = 48,
        }, text);

        rg.guiSetStyle(
            rg.GuiControl.default,
            rg.GuiControlProperty.text_alignment,
            @intFromEnum(rg.GuiTextAlignment.text_align_center),
        );
    }
}

pub fn handleAndDrawWindows() anyerror!void {
    windowsHandled = false;

    if (windows.items.len == 0) {
        return;
    }

    if (isDropdownActive()) {
        rg.guiLock();
    }

    var i: usize = windows.items.len - 1;

    while (i >= 0) {
        const window: *fw.GuiFloatWindow = windows.items[i];
        const handled: bool = window.update();

        if (handled) {
            windowsHandled = true;

            if (i < windows.items.len - 1) {
                const tempWindow: *fw.GuiFloatWindow = windows.orderedRemove(i);

                try windows.append(tempWindow);
            }

            break;
        }

        if (i == 0) {
            break;
        }

        i -= 1;
    }

    for (windows.items) |window| {
        window.draw();

        if (window == tilesWindow) {
            try handleAndDrawTilesWindow();
        } else if (window == clipboardWindow) {
            try handleAndDrawClipboardWindow();
        } else if (window == editorWindow) {
            try handleAndDrawEditorWindow();
        } else if (window == selectorWindow) {
            try handleAndDrawSelectorWindow();
        } else if (window == palleteWindow) {
            try handleAndDrawPalleteWindow();
        }
    }

    rg.guiUnlock();
}

pub fn handleAndDrawToolbar() anyerror!void {
    if (windowsHandled) {
        rg.guiLock();
    }

    // Toolbar
    rl.drawRectangle(0, 0, rl.getScreenWidth(), Consts.TOOLBAR_HEIGHT, backgroundColor);
    rl.drawLine(0, Consts.TOOLBAR_HEIGHT, rl.getScreenWidth(), Consts.TOOLBAR_HEIGHT, lineColor);

    // Tiles window
    _ = rg.guiGroupBox(.{ .x = 4, .y = 8, .width = 154, .height = Consts.TOOLBAR_HEIGHT - 12 }, "Tiles window");

    rl.drawTextEx(font, "Pixel size:", .{ .x = 12, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 12, .y = 28, .width = 70, .height = Consts.TOOLBAR_ITEM_HEIGHT }, "", &tilesPixelSize, Consts.TILES_PIXEL_SIZE_MIN, Consts.TILES_PIXEL_SIZE_MAX, false);

    if (tilesPixelSize != prevTilesPixelSize) {
        prevTilesPixelSize = tilesPixelSize;

        tilesWindow.setSize(Consts.TILES_TILES_PER_LINE * 8 * tilesPixelSize, Consts.TILES_LINES * 8 * tilesPixelSize);

        ensureWindowVisibility(tilesWindow);
    }

    rl.drawTextEx(font, "Show grid:", .{ .x = 90, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiToggle(.{ .x = 90, .y = 28, .width = 60, .height = Consts.TOOLBAR_ITEM_HEIGHT }, "#97#", &tilesGrid);

    // Clipboard window
    _ = rg.guiGroupBox(.{ .x = 162, .y = 8, .width = 154, .height = Consts.TOOLBAR_HEIGHT - 12 }, "Clipboard window");

    rl.drawTextEx(font, "Pixel size:", .{ .x = 170, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 170, .y = 28, .width = 70, .height = Consts.TOOLBAR_ITEM_HEIGHT }, "", &clipboardPixelSize, Consts.CLIPBOARD_PIXEL_SIZE_MIN, Consts.CLIPBOARD_PIXEL_SIZE_MAX, false);

    if (clipboardPixelSize != prevClipboardPixelSize) {
        prevClipboardPixelSize = clipboardPixelSize;

        clipboardWindow.setSize(Consts.CLIPBOARD_TILES_PER_LINE * 8 * clipboardPixelSize, Consts.CLIPBOARD_LINES * 8 * clipboardPixelSize);

        ensureWindowVisibility(clipboardWindow);
    }

    rl.drawTextEx(font, "Show grid:", .{ .x = 248, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiToggle(.{ .x = 248, .y = 28, .width = 60, .height = Consts.TOOLBAR_ITEM_HEIGHT }, "#97#", &clipboardGrid);

    // Editor window
    _ = rg.guiGroupBox(.{ .x = 320, .y = 8, .width = 232, .height = Consts.TOOLBAR_HEIGHT - 12 }, "Editor window");

    rl.drawTextEx(font, "Pixel size:", .{ .x = 328, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 328, .y = 28, .width = 70, .height = Consts.TOOLBAR_ITEM_HEIGHT }, "", &editorPixelSize, Consts.EDITOR_PIXEL_SIZE_MIN, Consts.EDITOR_PIXEL_SIZE_MAX, false);

    if (editorPixelSize != prevEditorPixelSize) {
        editorPixelSize = prevEditorPixelSize + (editorPixelSize - prevEditorPixelSize) * Consts.EDITOR_PIXEL_SIZE_MULTIPLIER;

        prevEditorPixelSize = editorPixelSize;

        editorWindow.setSize(editorPixelSize * 8 * editorTilesSquareSize, editorPixelSize * 8 * editorTilesSquareSize);

        ensureWindowVisibility(editorWindow);
    }

    rl.drawTextEx(font, "Show grid:", .{ .x = 406, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiToggle(.{ .x = 406, .y = 28, .width = 60, .height = Consts.TOOLBAR_ITEM_HEIGHT }, "#97#", &editorGrid);

    rl.drawTextEx(font, "Square size:", .{ .x = 474, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 474, .y = 28, .width = 70, .height = Consts.TOOLBAR_ITEM_HEIGHT }, "", &editorTilesSquareSize, Consts.EDITOR_SQUARE_SIZE_MIN, Consts.EDITOR_SQUARE_SIZE_MAX, false);

    if (editorTilesSquareSize != prevEditorTilesSquareSize) {
        prevEditorTilesSquareSize = editorTilesSquareSize;

        var x: i32 = @mod(@as(i32, @intCast(activeTile)), Consts.EDITOR_SQUARE_SIZE_MAX);
        var y: i32 = @divFloor(@as(i32, @intCast(activeTile)), Consts.EDITOR_SQUARE_SIZE_MAX);

        if (x >= editorTilesSquareSize) {
            x = editorTilesSquareSize - 1;
        }

        if (y >= editorTilesSquareSize) {
            y = editorTilesSquareSize - 1;
        }

        activeTile = y * Consts.EDITOR_SQUARE_SIZE_MAX + x;

        editorWindow.setSize(editorPixelSize * 8 * editorTilesSquareSize, editorPixelSize * 8 * editorTilesSquareSize);

        ensureWindowVisibility(editorWindow);
    }

    // File
    _ = rg.guiGroupBox(.{ .x = 556, .y = 8, .width = 296, .height = Consts.TOOLBAR_HEIGHT - 12 }, "File");

    rl.drawTextEx(font, "Pixel mode:", .{ .x = 564, .y = 16 }, 12, 0, lineColor);

    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiControlProperty.text_alignment,
        @intFromEnum(rg.GuiTextAlignment.text_align_left),
    );

    const pixelModeDropdownResult: i32 = rg.guiDropdownBox(
        .{ .x = 564, .y = 28, .width = 170, .height = Consts.TOOLBAR_ITEM_HEIGHT },
        " 1 BPP; 2 BPP NES; 2 BPP Virtual Boy; 2 BPP Neo Geo Pocket; 2 BPP GB, GBC; 3 BPP SNES; 4 BPP SMS, GG, WSC; 4 BPP Genesis; 4 BPP SNES; 4 BPP GBA; 8 BPP SNES; 8 BPP SNES (Mode7), GBA",
        &pixelMode,
        pixelModeDropdownActive,
    );

    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiControlProperty.text_alignment,
        @intFromEnum(rg.GuiTextAlignment.text_align_center),
    );

    if (pixelModeDropdownResult != 0) {
        pixelModeDropdownActive = !pixelModeDropdownActive;
    }

    if (pixelMode != prevPixelMode) {
        prevPixelMode = pixelMode;

        try loadPixelMode();
    }

    rl.drawTextEx(font, "Offset:", .{ .x = 742, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 742, .y = 28, .width = 70, .height = Consts.TOOLBAR_ITEM_HEIGHT }, "", &tilesOffset, 0, 16, false);

    if (tilesOffset != prevTilesOffset) {
        setROMOffset(tilesOffset);
    }

    if (romFileName == null) {
        rg.guiSetState(@intFromEnum(rg.GuiState.state_disabled));
    }

    const saveResult: i32 = rg.guiButton(.{
        .x = 820,
        .y = 28,
        .width = Consts.TOOLBAR_ITEM_HEIGHT,
        .height = Consts.TOOLBAR_ITEM_HEIGHT,
    }, "#2#");

    if (saveResult != 0) {
        saveROM();
    }

    if (romFileName == null) {
        rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));
    }

    // Application
    _ = rg.guiGroupBox(.{ .x = 856, .y = 8, .width = 116, .height = Consts.TOOLBAR_HEIGHT - 12 }, "Application");

    rl.drawTextEx(font, "Style:", .{ .x = 864, .y = 16 }, 12, 0, lineColor);

    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiControlProperty.text_alignment,
        @intFromEnum(rg.GuiTextAlignment.text_align_left),
    );

    const styleDropdownResult: i32 = rg.guiDropdownBox(
        .{ .x = 864, .y = 28, .width = 100, .height = Consts.TOOLBAR_ITEM_HEIGHT },
        " Amber; Ashes; Bluish; Candy; Cherry; Cyber; Dark; Enefete; Jungle; Lavanda; Sunny; Terminal",
        &styleIndex,
        styleDropdownActive,
    );

    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiControlProperty.text_alignment,
        @intFromEnum(rg.GuiTextAlignment.text_align_center),
    );

    if (styleDropdownResult != 0) {
        styleDropdownActive = !styleDropdownActive;
    }

    if (styleIndex != prevStyleIndex) {
        prevStyleIndex = styleIndex;

        loadStyle();
    }

    rg.guiUnlock();
}

pub fn drawStatusbar() anyerror!void {
    rl.drawRectangle(
        0,
        Consts.TOOLBAR_HEIGHT + fw.GuiFloatWindow.BORDER_WIDTH,
        rl.getScreenWidth(),
        Consts.STATUSBAR_HEIGHT,
        backgroundColor,
    );

    rl.drawLine(
        0,
        Consts.TOOLBAR_HEIGHT + Consts.STATUSBAR_HEIGHT + fw.GuiFloatWindow.BORDER_WIDTH,
        rl.getScreenWidth(),
        Consts.TOOLBAR_HEIGHT + Consts.STATUSBAR_HEIGHT + fw.GuiFloatWindow.BORDER_WIDTH,
        lineColor,
    );

    var buffer: [256]u8 = .{0} ** 256;

    const text: [:0]u8 = try std.fmt.bufPrintZ(
        &buffer,
        "Address: {X:0>8}        File name: {s}        File size: {d} bytes",
        .{
            @as(u32, @bitCast(romAddress + romOffset)),
            if (romFileName != null) rl.getFileName(romFileName.?) else "-",
            if (romData.len > 0) romData.len else 0,
        },
    );

    rl.drawTextEx(font, text, .{ .x = 4, .y = Consts.TOOLBAR_HEIGHT + 6 }, 16, 0, lineColor);
}

pub fn main() anyerror!u8 {
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    gpa_allocator = gpa.allocator();

    rl.setConfigFlags(.{ .window_resizable = true });

    rl.initWindow(
        976,
        Consts.TOOLBAR_HEIGHT + 32 + fw.GuiFloatWindow.HEADER_HEIGHT + 2 * fw.GuiFloatWindow.BORDER_WIDTH + Consts.TILES_LINES * 8 * tilesPixelSize + 32,
        "Startile",
    );
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    font = try rl.loadFontFromMemory(".ttf", Consts.FONT_DATA, 96, null);
    defer rl.unloadFont(font);

    loadStyle();

    resetAll();

    try loadPixelMode();

    tilesWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        32,
        Consts.TOOLBAR_HEIGHT + 32,
        Consts.TILES_TILES_PER_LINE * 8 * tilesPixelSize,
        Consts.TILES_LINES * 8 * tilesPixelSize,
        "Tiles",
        true,
        false,
    );
    defer tilesWindow.deinit();

    try tilesWindow.addEventListener(&tilesWindowEventHandler);

    clipboardWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        @as(i32, @intFromFloat(tilesWindow.windowRect.x + tilesWindow.windowRect.width)) + 32,
        @as(i32, @intFromFloat(tilesWindow.windowRect.y)),
        Consts.CLIPBOARD_TILES_PER_LINE * 8 * tilesPixelSize,
        Consts.CLIPBOARD_LINES * 8 * tilesPixelSize,
        "Clipboard",
        false,
        false,
    );
    defer clipboardWindow.deinit();

    try clipboardWindow.addEventListener(&clipboardWindowEventHandler);

    editorWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        @as(i32, @intFromFloat(clipboardWindow.windowRect.x)),
        @as(i32, @intFromFloat(clipboardWindow.windowRect.y + clipboardWindow.windowRect.height)) + 32,
        editorPixelSize * 8 * editorTilesSquareSize,
        editorPixelSize * 8 * editorTilesSquareSize,
        "Editor",
        false,
        false,
    );
    defer editorWindow.deinit();

    try editorWindow.addEventListener(&editorWindowEventHandler);

    palleteWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        @as(i32, @intFromFloat(editorWindow.windowRect.x + editorWindow.windowRect.width)) + 32,
        @as(i32, @intFromFloat(editorWindow.windowRect.y)),
        Consts.PALLETE_AREA_SIZE,
        Consts.PALLETE_AREA_SIZE + 88,
        "Pallete",
        false,
        false,
    );
    defer palleteWindow.deinit();

    try palleteWindow.addEventListener(&palleteWindowEventHandler);

    selectorWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        @as(i32, @intFromFloat(editorWindow.windowRect.x)),
        @as(i32, @intFromFloat(editorWindow.windowRect.y + editorWindow.windowRect.height)) + 32,
        Consts.SELECTOR_BUTTON_SIZE * 4,
        Consts.SELECTOR_BUTTON_SIZE * 4,
        "Active tile",
        false,
        false,
    );
    defer selectorWindow.deinit();

    windows = std.ArrayList(*fw.GuiFloatWindow).init(gpa_allocator);
    defer windows.deinit();

    try windows.append(tilesWindow);
    try windows.append(clipboardWindow);
    try windows.append(editorWindow);
    try windows.append(palleteWindow);
    try windows.append(selectorWindow);

    rl.setWindowMinSize(
        976,
        Consts.TOOLBAR_HEIGHT + Consts.STATUSBAR_HEIGHT + fw.GuiFloatWindow.HEADER_HEIGHT + fw.GuiFloatWindow.BORDER_WIDTH,
    );

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        mousePosition = rl.getMousePosition();

        rl.clearBackground(backgroundColor);

        handleDroppedFiles: {
            if (rl.isFileDropped()) {
                const filePaths: rl.FilePathList = rl.loadDroppedFiles();
                defer rl.unloadDroppedFiles(filePaths);

                if (filePaths.count == 0) {
                    break :handleDroppedFiles;
                }

                try loadROM(filePaths.paths[0][0..]);
            }
        }

        handleInputs();

        try handleAndDrawWindows();

        try drawStatusbar();

        try handleAndDrawToolbar();

        const screenWidth: i32 = rl.getScreenWidth();
        const screenHeight: i32 = rl.getScreenHeight();

        if (screenWidth != prevScreenWidth or screenHeight != prevScreenHeight) {
            prevScreenWidth = screenWidth;
            prevScreenHeight = screenHeight;

            ensureWindowsVisibility();
        }
    }

    if (romFileName != null) {
        gpa_allocator.free(romFileName.?);
    }

    return 0;
}
