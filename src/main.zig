const std: type = @import("std");
const rl: type = @import("raylib");
const rg: type = @import("raygui");
const fw: type = @import("GuiFloatWindow.zig");
const sb: type = @import("GuiScrollbar.zig");
const Consts: type = @import("Consts.zig");

var font: rl.Font = undefined;

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

var tileActive: i32 = 0;

var pallete: [256]rl.Color = .{rl.Color.black} ** 256;
var palleteCount: usize = 2;
var palleteRows: i32 = 1;
var palleteColumns: i32 = 1;

var clipboardData: [8 * 8 * Consts.CLIPBOARD_TILES_PER_LINE * Consts.CLIPBOARD_LINES]u8 = .{0} ** (8 * 8 * Consts.CLIPBOARD_TILES_PER_LINE * Consts.CLIPBOARD_LINES);
var editorData: [8 * 8 * Consts.EDITOR_SQUARE_SIZE_MAX * Consts.EDITOR_SQUARE_SIZE_MAX]u8 = .{0} ** (8 * 8 * Consts.EDITOR_SQUARE_SIZE_MAX * Consts.EDITOR_SQUARE_SIZE_MAX);

var prevPixelMode: i32 = 4;
var pixelMode: i32 = 4;
var pixelModeDropdownActive: bool = false;

var editorForegroundColorIndex: u8 = 1;
var editorBackgroundColorIndex: u8 = 0;

var colorPickerColor: rl.Color = rl.Color.black;

pub fn isForegroundWindow(window: *fw.GuiFloatWindow) bool {
    if (windows.items.len == 0) {
        return false;
    }

    return windows.items[windows.items.len - 1] == window;
}

pub fn isDropdownActive() bool {
    return pixelModeDropdownActive;
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

pub fn loadPixelModePallete() void {
    for (0..pallete.len) |i| {
        pallete[i] = rl.Color.black;
    }

    const mode: Consts.PixelMode = @enumFromInt(pixelMode);

    switch (mode) {
        .one_bpp => {
            pallete[0] = rl.Color.black;
            pallete[1] = rl.Color.white;

            palleteCount = 2;
            palleteRows = 2;
            palleteColumns = 1;
        },
        .two_bpp_gb_gbc => {
            pallete[0] = rl.Color.black;
            pallete[1] = rl.Color.gray;
            pallete[2] = rl.Color.light_gray;
            pallete[3] = rl.Color.white;

            palleteCount = 4;
            palleteRows = 2;
            palleteColumns = 2;
        },
        .eight_bpp_snes => {
            initializePallete();
        },
        else => {},
    }

    editorForegroundColorIndex = @as(u8, @intCast(palleteCount - 1));
    editorBackgroundColorIndex = 0;
}

pub fn loadPixelMode() anyerror!void {
    loadPixelModePallete();
    // TODO
}

pub fn ensureWindowVisibility(window: *fw.GuiFloatWindow) void {
    const left: f32 = window.windowRect.x;
    const top: f32 = window.windowRect.y;
    const right: f32 = window.windowRect.x + window.windowRect.width;
    const limitTop: f32 = @as(f32, @floatFromInt(Consts.TOOLBAR_HEIGHT));
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

    const mousePosition: rl.Vector2 = rl.getMousePosition();

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

pub fn windowEventHandler(event: fw.GuiFloatWindowEvent) void {
    switch (event) {
        .scroll_vertical_moved => |arguments| {
            std.log.info("JANELA {s} ROLOU VERTICALMENTE PARA {d}", .{ arguments.window.title, arguments.value });
        },
        .scroll_horizontal_moved => |arguments| {
            std.log.info("JANELA {s} ROLOU HORIZONTALMENTE PARA {d}", .{ arguments.window.title, arguments.value });
        },
        else => {
            std.log.info("EVENTO {any} NAO HANDLED", .{event});
        },
    }
}

pub fn clipboardWindowEventHandler(event: fw.GuiFloatWindowEvent) void {
    var handled: bool = false;

    var clipboardTileX: i32 = undefined;
    var clipboardTileY: i32 = undefined;
    var clipboardTileIndex: usize = undefined;

    var editorTileIndex: usize = undefined;

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
            editorTileIndex = @as(usize, @intCast(tileActive * 8 * 8));
        },
        else => {},
    }

    if (!handled) {
        return;
    }

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
    const mousePosition: rl.Vector2 = rl.getMousePosition();
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
    const mousePosition: rl.Vector2 = rl.getMousePosition();

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
    const mousePosition: rl.Vector2 = rl.getMousePosition();

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
    const mousePosition: rl.Vector2 = rl.getMousePosition();

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

        rg.guiSetStyle(rg.GuiControl.default, rg.GuiDefaultProperty.text_size, 32);

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

            if (i == tileActive) {
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

            if (i == tileActive) {
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
            tileActive = @as(i32, @intCast(i));
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

    const mousePosition: rl.Vector2 = rl.getMousePosition();
    const colorsRect: rl.Rectangle = .{
        .x = palleteWindow.bodyRect.x,
        .y = palleteWindow.bodyRect.y,
        .width = Consts.PALLETE_AREA_SIZE,
        .height = Consts.PALLETE_AREA_SIZE,
    };

    if (rl.checkCollisionPointRec(mousePosition, colorsRect) and getWindowUnderMouse() == palleteWindow) {
        const localX: i32 = @as(i32, @intFromFloat(mousePosition.x)) - bodyX;
        const localY: i32 = @as(i32, @intFromFloat(mousePosition.y)) - bodyY;
        const colorX: i32 = @divFloor(localX, colorWidth);
        const colorY: i32 = @divFloor(localY, colorHeight);

        rl.drawRectangle(bodyX + colorX * colorWidth, bodyY + colorY * colorHeight, colorWidth, colorHeight, selectedColor);

        rl.drawRectangleLines(bodyX + colorX * colorWidth, bodyY + colorY * colorHeight, colorWidth, colorHeight, lineColor);
    }

    rl.drawRectangle(bodyX + 32, bodyY + Consts.PALLETE_AREA_SIZE + 32, 48, 48, pallete[editorBackgroundColorIndex]);
    rl.drawRectangleLines(bodyX + 32, bodyY + Consts.PALLETE_AREA_SIZE + 32, 48, 48, lineColor);

    rl.drawRectangle(bodyX + 8, bodyY + Consts.PALLETE_AREA_SIZE + 8, 48, 48, pallete[editorForegroundColorIndex]);
    rl.drawRectangleLines(bodyX + 8, bodyY + Consts.PALLETE_AREA_SIZE + 8, 48, 48, lineColor);

    const swapButtonResult: i32 = rg.guiButton(.{
        .x = @as(f32, @floatFromInt(bodyX + 8)),
        .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 56)),
        .width = 24,
        .height = 24,
    }, "#77#");

    if (swapButtonResult != 0) {
        const tempColorIndex: u8 = editorForegroundColorIndex;

        editorForegroundColorIndex = editorBackgroundColorIndex;
        editorBackgroundColorIndex = tempColorIndex;
    }

    _ = rg.guiColorPicker(.{
        .x = @as(f32, @floatFromInt(bodyX + 88)),
        .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 8)),
        .width = Consts.PALLETE_AREA_SIZE - 120,
        .height = 48,
    }, "", &colorPickerColor);

    const setButtonsWidth: i32 = @divFloor(Consts.PALLETE_AREA_SIZE - 96, 2);

    const setForegroundResult: i32 = rg.guiButton(.{
        .x = @as(f32, @floatFromInt(bodyX + 88)),
        .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 56)),
        .width = setButtonsWidth,
        .height = 24,
    }, "Set FG");

    if (setForegroundResult != 0) {
        pallete[editorForegroundColorIndex] = colorPickerColor;
    }

    const setBackgroundResult: i32 = rg.guiButton(.{
        .x = @as(f32, @floatFromInt(bodyX + 88 + setButtonsWidth)),
        .y = @as(f32, @floatFromInt(bodyY + Consts.PALLETE_AREA_SIZE + 56)),
        .width = setButtonsWidth,
        .height = 24,
    }, "Set BG");

    if (setBackgroundResult != 0) {
        pallete[editorBackgroundColorIndex] = colorPickerColor;
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
    const backgroundColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.background_color))));

    if (windowsHandled) {
        rg.guiLock();
    }

    // Toolbar
    rl.drawRectangle(0, 0, rl.getScreenWidth(), Consts.TOOLBAR_HEIGHT, backgroundColor);
    rl.drawLine(0, Consts.TOOLBAR_HEIGHT, rl.getScreenWidth(), Consts.TOOLBAR_HEIGHT, lineColor);

    // Tiles window
    _ = rg.guiGroupBox(.{ .x = 4, .y = 8, .width = 154, .height = Consts.TOOLBAR_HEIGHT - 12 }, "Tiles window");

    rl.drawTextEx(font, "Pixel size:", .{ .x = 12, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 12, .y = 28, .width = 70, .height = 24 }, "", &tilesPixelSize, Consts.TILES_PIXEL_SIZE_MIN, Consts.TILES_PIXEL_SIZE_MAX, false);

    if (tilesPixelSize != prevTilesPixelSize) {
        prevTilesPixelSize = tilesPixelSize;

        tilesWindow.setSize(Consts.TILES_TILES_PER_LINE * 8 * tilesPixelSize, Consts.TILES_LINES * 8 * tilesPixelSize);

        ensureWindowVisibility(tilesWindow);
    }

    rl.drawTextEx(font, "Show grid:", .{ .x = 90, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiToggle(.{ .x = 90, .y = 28, .width = 60, .height = 24 }, "#97#", &tilesGrid);

    // Clipboard window
    _ = rg.guiGroupBox(.{ .x = 162, .y = 8, .width = 154, .height = Consts.TOOLBAR_HEIGHT - 12 }, "Clipboard window");

    rl.drawTextEx(font, "Pixel size:", .{ .x = 170, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 170, .y = 28, .width = 70, .height = 24 }, "", &clipboardPixelSize, Consts.CLIPBOARD_PIXEL_SIZE_MIN, Consts.CLIPBOARD_PIXEL_SIZE_MAX, false);

    if (clipboardPixelSize != prevClipboardPixelSize) {
        prevClipboardPixelSize = clipboardPixelSize;

        clipboardWindow.setSize(Consts.CLIPBOARD_TILES_PER_LINE * 8 * clipboardPixelSize, Consts.CLIPBOARD_LINES * 8 * clipboardPixelSize);

        ensureWindowVisibility(clipboardWindow);
    }

    rl.drawTextEx(font, "Show grid:", .{ .x = 248, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiToggle(.{ .x = 248, .y = 28, .width = 60, .height = 24 }, "#97#", &clipboardGrid);

    // Editor window
    _ = rg.guiGroupBox(.{ .x = 320, .y = 8, .width = 232, .height = Consts.TOOLBAR_HEIGHT - 12 }, "Editor window");

    rl.drawTextEx(font, "Pixel size:", .{ .x = 328, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 328, .y = 28, .width = 70, .height = 24 }, "", &editorPixelSize, Consts.EDITOR_PIXEL_SIZE_MIN, Consts.EDITOR_PIXEL_SIZE_MAX, false);

    if (editorPixelSize != prevEditorPixelSize) {
        editorPixelSize = prevEditorPixelSize + (editorPixelSize - prevEditorPixelSize) * Consts.EDITOR_PIXEL_SIZE_MULTIPLIER;

        prevEditorPixelSize = editorPixelSize;

        editorWindow.setSize(editorPixelSize * 8 * editorTilesSquareSize, editorPixelSize * 8 * editorTilesSquareSize);

        ensureWindowVisibility(editorWindow);
    }

    rl.drawTextEx(font, "Show grid:", .{ .x = 406, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiToggle(.{ .x = 406, .y = 28, .width = 60, .height = 24 }, "#97#", &editorGrid);

    rl.drawTextEx(font, "Square size:", .{ .x = 474, .y = 16 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 474, .y = 28, .width = 70, .height = 24 }, "", &editorTilesSquareSize, Consts.EDITOR_SQUARE_SIZE_MIN, Consts.EDITOR_SQUARE_SIZE_MAX, false);

    if (editorTilesSquareSize != prevEditorTilesSquareSize) {
        prevEditorTilesSquareSize = editorTilesSquareSize;

        var x: i32 = @mod(@as(i32, @intCast(tileActive)), Consts.EDITOR_SQUARE_SIZE_MAX);
        var y: i32 = @divFloor(@as(i32, @intCast(tileActive)), Consts.EDITOR_SQUARE_SIZE_MAX);

        if (x >= editorTilesSquareSize) {
            x = editorTilesSquareSize - 1;
        }

        if (y >= editorTilesSquareSize) {
            y = editorTilesSquareSize - 1;
        }

        tileActive = y * Consts.EDITOR_SQUARE_SIZE_MAX + x;

        editorWindow.setSize(editorPixelSize * 8 * editorTilesSquareSize, editorPixelSize * 8 * editorTilesSquareSize);

        ensureWindowVisibility(editorWindow);
    }

    // Pixel mode
    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiControlProperty.text_alignment,
        @intFromEnum(rg.GuiTextAlignment.text_align_left),
    );

    rl.drawTextEx(font, "Pixel mode:", .{ .x = 558, .y = 16 }, 12, 0, lineColor);

    const pixelModeDropdownResult: i32 = rg.guiDropdownBox(
        .{ .x = 558, .y = 28, .width = 170, .height = 24 },
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

    rg.guiUnlock();
}

pub fn main() anyerror!u8 {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator: std.mem.Allocator = gpa.allocator();

    rl.setConfigFlags(.{ .window_resizable = true });

    rl.initWindow(1280, 720, "Startile");
    defer rl.closeWindow();

    rl.setWindowMinSize(
        556,
        Consts.TOOLBAR_HEIGHT + fw.GuiFloatWindow.HEADER_HEIGHT,
    );

    rl.setTargetFPS(60);

    rg.guiLoadStyle("resources/style_jungle.rgs");

    font = try rl.loadFontFromMemory(".ttf", Consts.FONT_DATA, 20, null);
    defer rl.unloadFont(font);

    rg.guiSetFont(font);

    rg.guiSetStyle(
        rg.GuiControl.default,
        rg.GuiControlProperty.text_alignment,
        @intFromEnum(rg.GuiTextAlignment.text_align_center),
    );

    lineColor = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.line_color))));

    selectedColor = rl.colorAlpha(
        rl.Color.fromInt(
            @as(u32, @intCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.base_color_focused))),
        ),
        0.5,
    );

    initializePallete();
    try loadPixelMode();

    const backgroundColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.background_color))));

    tilesWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        32,
        Consts.TOOLBAR_HEIGHT + 16,
        Consts.TILES_TILES_PER_LINE * 8 * tilesPixelSize,
        Consts.TILES_LINES * 8 * tilesPixelSize,
        "Tiles",
        true,
        false,
    );
    defer tilesWindow.deinit();

    try tilesWindow.addEventListener(&windowEventHandler);

    clipboardWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        @as(i32, @intFromFloat(tilesWindow.windowRect.x + tilesWindow.windowRect.width)) + 32,
        Consts.TOOLBAR_HEIGHT + 16,
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
        @as(i32, @intFromFloat(palleteWindow.windowRect.x)),
        @as(i32, @intFromFloat(palleteWindow.windowRect.y + palleteWindow.windowRect.height)) + 32,
        Consts.SELECTOR_BUTTON_SIZE * 4,
        Consts.SELECTOR_BUTTON_SIZE * 4,
        "Active tile",
        false,
        false,
    );
    defer selectorWindow.deinit();

    try selectorWindow.addEventListener(&windowEventHandler);

    windows = std.ArrayList(*fw.GuiFloatWindow).init(gpa_allocator);
    defer windows.deinit();

    try windows.append(tilesWindow);
    try windows.append(clipboardWindow);
    try windows.append(editorWindow);
    try windows.append(palleteWindow);
    try windows.append(selectorWindow);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(backgroundColor);

        try handleAndDrawWindows();

        try handleAndDrawToolbar();

        const screenWidth: i32 = rl.getScreenWidth();
        const screenHeight: i32 = rl.getScreenHeight();

        if (screenWidth != prevScreenWidth or screenHeight != prevScreenHeight) {
            prevScreenWidth = screenWidth;
            prevScreenHeight = screenHeight;

            ensureWindowsVisibility();
        }
    }

    return 0;
}
