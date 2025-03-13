const std: type = @import("std");
const rl: type = @import("raylib");
const rg: type = @import("raygui");
const fw: type = @import("GuiFloatWindow.zig");
const sb: type = @import("GuiScrollbar.zig");
const Consts: type = @import("Consts.zig");

var font: rl.Font = undefined;

var prevScreenWidth: i32 = undefined;
var prevScreenHeight: i32 = undefined;

var tilesWindow: *fw.GuiFloatWindow = undefined;
var clipboardWindow: *fw.GuiFloatWindow = undefined;
var tileEditorWindow: *fw.GuiFloatWindow = undefined;
var palleteWindow: *fw.GuiFloatWindow = undefined;
var tileSelectorWindow: *fw.GuiFloatWindow = undefined;

var windows: std.ArrayList(*fw.GuiFloatWindow) = undefined;

var showGrids: bool = true;

var prevPixelSize: i32 = 3;
var pixelSize: i32 = 3;

var prevEditorPixelSizeIndex: i32 = 3;
var editorPixelSizeIndex: i32 = 3;
var editorPixelSize: i32 = 12;

var prevNumEditorTiles: i32 = 1;
var numEditorTiles: i32 = 1;

var tileActive: i32 = 0;

var pallete: [256]rl.Color = .{rl.Color.black} ** 256;
var editorData: [8 * 8 * 16]u8 = .{0} ** (8 * 8 * 16);

pub fn isForegroundWindow(window: *fw.GuiFloatWindow) bool {
    if (windows.items.len == 0) {
        return false;
    }

    return windows.items[windows.items.len - 1] == window;
}

pub fn initializePallete() void {
    for (0..pallete.len) |i| {
        const value: u8 = @as(u8, @intCast(i));

        pallete[i] = rl.Color.init(value, value, value, 255);
    }
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

pub fn tileEditorWindowEventHandler(event: fw.GuiFloatWindowEvent) void {
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
            colorIndex = 255;
        },
        .right_click_start, .right_click_moved => {
            colorIndex = 0;
        },
        else => {},
    }

    if (drawing) {
        editorData[pixelIndex] = colorIndex;
    }
}

pub fn handleAndDrawTilesWindow() anyerror!void {
    const mousePosition: rl.Vector2 = rl.getMousePosition();

    var selectedColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.base_color_focused))));

    selectedColor.a = 128;

    if (showGrids) {
        var mouseCell: rl.Vector2 = undefined;

        _ = rg.guiGrid(tilesWindow.bodyRect, "", @as(f32, @floatFromInt(8 * pixelSize)), 1, &mouseCell);
    }

    if (rl.checkCollisionPointRec(mousePosition, tilesWindow.bodyRect)) {
        const localX: f32 = mousePosition.x - tilesWindow.bodyRect.x;
        const localY: f32 = mousePosition.y - tilesWindow.bodyRect.y;
        const cellX: f32 = @divFloor(localX, 8 * @as(f32, @floatFromInt(pixelSize)));
        const cellY: f32 = @divFloor(localY, 8 * @as(f32, @floatFromInt(pixelSize)));

        rl.drawRectangle(
            @as(i32, @intFromFloat(tilesWindow.bodyRect.x)) + @as(i32, @intFromFloat(cellX)) * 8 * pixelSize,
            @as(i32, @intFromFloat(tilesWindow.bodyRect.y)) + @as(i32, @intFromFloat(cellY)) * 8 * pixelSize,
            8 * pixelSize,
            8 * pixelSize,
            selectedColor,
        );
    }
}

pub fn handleAndDrawClipboardWindow() anyerror!void {
    const mousePosition: rl.Vector2 = rl.getMousePosition();

    var selectedColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.base_color_focused))));

    selectedColor.a = 128;

    if (showGrids) {
        var mouseCell: rl.Vector2 = undefined;

        _ = rg.guiGrid(clipboardWindow.bodyRect, "", @as(f32, @floatFromInt(8 * pixelSize)), 1, &mouseCell);
    }

    if (rl.checkCollisionPointRec(mousePosition, clipboardWindow.bodyRect)) {
        const localX: f32 = mousePosition.x - clipboardWindow.bodyRect.x;
        const localY: f32 = mousePosition.y - clipboardWindow.bodyRect.y;
        const cellX: f32 = @divFloor(localX, 8 * @as(f32, @floatFromInt(pixelSize)));
        const cellY: f32 = @divFloor(localY, 8 * @as(f32, @floatFromInt(pixelSize)));

        rl.drawRectangle(
            @as(i32, @intFromFloat(clipboardWindow.bodyRect.x)) + @as(i32, @intFromFloat(cellX)) * 8 * pixelSize,
            @as(i32, @intFromFloat(clipboardWindow.bodyRect.y)) + @as(i32, @intFromFloat(cellY)) * 8 * pixelSize,
            8 * pixelSize,
            8 * pixelSize,
            selectedColor,
        );
    }
}

pub fn handleAndDrawTileEditorWindow() anyerror!void {
    const mousePosition: rl.Vector2 = rl.getMousePosition();
    const numActiveTiles: i32 = numEditorTiles + 1;

    var selectedColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.base_color_focused))));

    selectedColor.a = 128;

    for (0..editorData.len) |i| {
        const tile: i32 = @divFloor(@as(i32, @intCast(i)), 8 * 8);
        const leftover: i32 = @mod(@as(i32, @intCast(i)), 8 * 8);
        const tileX: i32 = @mod(tile, 4);
        const tileY: i32 = @divFloor(tile, 4);
        const pixelX: i32 = @mod(leftover, 8);
        const pixelY: i32 = @divFloor(leftover, 8);
        const color: rl.Color = pallete[editorData[i]];

        if (tileX >= numActiveTiles or tileY >= numActiveTiles) {
            continue;
        }

        rl.drawRectangle(
            @as(i32, @intFromFloat(tileEditorWindow.bodyRect.x)) + tileX * 8 * editorPixelSize + pixelX * editorPixelSize,
            @as(i32, @intFromFloat(tileEditorWindow.bodyRect.y)) + tileY * 8 * editorPixelSize + pixelY * editorPixelSize,
            editorPixelSize,
            editorPixelSize,
            color,
        );
    }

    if (showGrids) {
        var mouseCell: rl.Vector2 = undefined;

        _ = rg.guiGrid(tileEditorWindow.bodyRect, "", @as(f32, @floatFromInt(editorPixelSize * 8)), 8, &mouseCell);
    }

    if (rl.checkCollisionPointRec(mousePosition, tileEditorWindow.bodyRect)) {
        const localX: f32 = mousePosition.x - tileEditorWindow.bodyRect.x;
        const localY: f32 = mousePosition.y - tileEditorWindow.bodyRect.y;
        const cellX: f32 = @divFloor(localX, @as(f32, @floatFromInt(editorPixelSize)));
        const cellY: f32 = @divFloor(localY, @as(f32, @floatFromInt(editorPixelSize)));

        rl.drawRectangle(
            @as(i32, @intFromFloat(tileEditorWindow.bodyRect.x)) + @as(i32, @intFromFloat(cellX)) * editorPixelSize,
            @as(i32, @intFromFloat(tileEditorWindow.bodyRect.y)) + @as(i32, @intFromFloat(cellY)) * editorPixelSize,
            editorPixelSize,
            editorPixelSize,
            selectedColor,
        );
    }
}

pub fn handleAndDrawTileSelectorWindow() anyerror!void {
    const numActiveTiles: i32 = numEditorTiles + 1;

    var buffer: [3]u8 = .{0} ** 3;

    for (0..16) |i| {
        const x: i32 = @mod(@as(i32, @intCast(i)), 4);
        const y: i32 = @divFloor(@as(i32, @intCast(i)), 4);
        const text: [:0]u8 = try std.fmt.bufPrintZ(&buffer, "{d}", .{i + 1});

        if (x >= numActiveTiles or y >= numActiveTiles) {
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
                .x = tileSelectorWindow.bodyRect.x + @as(f32, @floatFromInt(x)) * 24,
                .y = tileSelectorWindow.bodyRect.y + @as(f32, @floatFromInt(y)) * 24,
                .width = 24,
                .height = 24,
            },
            text,
        );

        if (ret == 1 and isForegroundWindow(tileSelectorWindow)) {
            tileActive = @as(i32, @intCast(i));
        }
    }

    rg.guiSetState(@intFromEnum(rg.GuiState.state_normal));
}

pub fn handleAndDrawWindows() anyerror!void {
    if (windows.items.len == 0) {
        return;
    }

    var i: usize = windows.items.len - 1;

    while (i >= 0) {
        const window: *fw.GuiFloatWindow = windows.items[i];
        const handled: bool = window.update();

        if (handled) {
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
        } else if (window == tileEditorWindow) {
            try handleAndDrawTileEditorWindow();
        } else if (window == tileSelectorWindow) {
            try handleAndDrawTileSelectorWindow();
        }
    }
}

pub fn handleAndDrawToolbar() anyerror!void {
    const backgroundColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.background_color))));
    const lineColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.line_color))));

    rl.drawRectangle(0, 0, rl.getScreenWidth(), Consts.TOOLBAR_HEIGHT, backgroundColor);
    rl.drawLine(0, Consts.TOOLBAR_HEIGHT, rl.getScreenWidth(), Consts.TOOLBAR_HEIGHT, lineColor);

    rl.drawTextEx(font, "Pixel size:", .{ .x = 8, .y = 6 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 8, .y = 18, .width = 70, .height = 24 }, "", &pixelSize, 1, 4, false);

    if (pixelSize != prevPixelSize) {
        prevPixelSize = pixelSize;

        tilesWindow.setSize(Consts.TILES_PER_LINE * 8 * pixelSize, Consts.TILES_LINES * 8 * pixelSize);
        clipboardWindow.setSize(16 * 8 * pixelSize, 8 * 8 * pixelSize);

        ensureWindowVisibility(tilesWindow);
        ensureWindowVisibility(clipboardWindow);
    }

    rl.drawTextEx(font, "Tiles in editor:", .{ .x = 86, .y = 6 }, 12, 0, lineColor);

    _ = rg.guiComboBox(
        .{ .x = 86, .y = 18, .width = 100, .height = 24 },
        "1x1;2x2;3x3;4x4",
        &numEditorTiles,
    );

    if (numEditorTiles != prevNumEditorTiles) {
        prevNumEditorTiles = numEditorTiles;

        const numActiveTiles: i32 = numEditorTiles + 1;

        var x: i32 = @mod(@as(i32, @intCast(tileActive)), 4);
        var y: i32 = @divFloor(@as(i32, @intCast(tileActive)), 4);

        if (x >= numActiveTiles) {
            x = numEditorTiles;
        }

        if (y >= numActiveTiles) {
            y = numEditorTiles;
        }

        tileActive = y * 4 + x;

        tileEditorWindow.setSize(editorPixelSize * 8 * (numEditorTiles + 1), editorPixelSize * 8 * (numEditorTiles + 1));

        ensureWindowVisibility(tileEditorWindow);
    }

    rl.drawTextEx(font, "Show grid:", .{ .x = 194, .y = 6 }, 12, 0, lineColor);

    _ = rg.guiToggle(.{ .x = 194, .y = 18, .width = 60, .height = 24 }, "#97#", &showGrids);

    rl.drawTextEx(font, "Editor pixel size:", .{ .x = 262, .y = 6 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 262, .y = 18, .width = 110, .height = 24 }, "", &editorPixelSizeIndex, 1, 6, false);

    if (editorPixelSizeIndex != prevEditorPixelSizeIndex) {
        prevEditorPixelSizeIndex = editorPixelSizeIndex;

        editorPixelSize = editorPixelSizeIndex * 4;

        tileEditorWindow.setSize(editorPixelSize * 8 * (numEditorTiles + 1), editorPixelSize * 8 * (numEditorTiles + 1));

        ensureWindowVisibility(tileEditorWindow);
    }
}

pub fn main() anyerror!u8 {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator: std.mem.Allocator = gpa.allocator();

    rl.setConfigFlags(.{ .window_resizable = true });

    rl.initWindow(1280, 720, "Startile");
    defer rl.closeWindow();

    rl.setWindowMinSize(
        Consts.TILES_PER_LINE * 8 * 4 + fw.GuiFloatWindow.SCROLLBAR_SIZE + 2 * fw.GuiFloatWindow.BORDER_WIDTH,
        Consts.TOOLBAR_HEIGHT + fw.GuiFloatWindow.HEADER_HEIGHT,
    );

    rl.setTargetFPS(60);

    rg.guiLoadStyle("resources/style_jungle.rgs");

    font = try rl.loadFontFromMemory(".ttf", Consts.FONT_DATA, 20, null);
    defer rl.unloadFont(font);

    rg.guiSetFont(font);

    initializePallete();

    const backgroundColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.background_color))));

    tilesWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        32,
        Consts.TOOLBAR_HEIGHT + 16,
        Consts.TILES_PER_LINE * 8 * pixelSize,
        Consts.TILES_LINES * 8 * pixelSize,
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
        16 * 8 * pixelSize,
        8 * 8 * pixelSize,
        "Clipboard",
        false,
        false,
    );
    defer clipboardWindow.deinit();

    try clipboardWindow.addEventListener(&windowEventHandler);

    tileEditorWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        @as(i32, @intFromFloat(clipboardWindow.windowRect.x)),
        @as(i32, @intFromFloat(clipboardWindow.windowRect.y + clipboardWindow.windowRect.height)) + 32,
        editorPixelSize * 8 * (numEditorTiles + 1),
        editorPixelSize * 8 * (numEditorTiles + 1),
        "Editor",
        false,
        false,
    );
    defer tileEditorWindow.deinit();

    try tileEditorWindow.addEventListener(&tileEditorWindowEventHandler);

    palleteWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        @as(i32, @intFromFloat(tileEditorWindow.windowRect.x + tileEditorWindow.windowRect.width)) + 32,
        @as(i32, @intFromFloat(tileEditorWindow.windowRect.y)),
        150,
        150,
        "Pallete",
        false,
        false,
    );
    defer palleteWindow.deinit();

    try palleteWindow.addEventListener(&windowEventHandler);

    tileSelectorWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        @as(i32, @intFromFloat(palleteWindow.windowRect.x)),
        @as(i32, @intFromFloat(palleteWindow.windowRect.y + palleteWindow.windowRect.height)) + 32,
        24 * 4,
        24 * 4,
        "Active tile",
        false,
        false,
    );
    defer tileSelectorWindow.deinit();

    try tileSelectorWindow.addEventListener(&windowEventHandler);

    windows = std.ArrayList(*fw.GuiFloatWindow).init(gpa_allocator);
    defer windows.deinit();

    try windows.append(tilesWindow);
    try windows.append(clipboardWindow);
    try windows.append(tileEditorWindow);
    try windows.append(palleteWindow);
    try windows.append(tileSelectorWindow);

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
