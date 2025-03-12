const std: type = @import("std");
const rl: type = @import("raylib");
const rg: type = @import("raygui");
const fw: type = @import("GuiFloatWindow.zig");
const sb: type = @import("GuiScrollbar.zig");
const Consts: type = @import("Consts.zig");

var font: rl.Font = undefined;

var tilesWindow: *fw.GuiFloatWindow = undefined;
var clipboardWindow: *fw.GuiFloatWindow = undefined;
var tileEditorWindow: *fw.GuiFloatWindow = undefined;
var tileSelectorWindow: *fw.GuiFloatWindow = undefined;

var windows: std.ArrayList(*fw.GuiFloatWindow) = undefined;

var prevPixelSize: i32 = 2;
var pixelSize: i32 = 2;

var prevNumEditorTiles: i32 = 1;
var numEditorTiles: i32 = 1;

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
    }
}

pub fn handleAndDrawToolbar() anyerror!void {
    const backgroundColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.background_color))));
    const lineColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.line_color))));

    rl.drawRectangle(0, 0, rl.getScreenWidth(), Consts.TOOLBAR_HEIGHT, backgroundColor);
    rl.drawLine(0, Consts.TOOLBAR_HEIGHT, rl.getScreenWidth(), Consts.TOOLBAR_HEIGHT, lineColor);

    rl.drawTextEx(font, "Pixel size:", .{ .x = 8, .y = 6 }, 12, 0, lineColor);

    _ = rg.guiSpinner(.{ .x = 8, .y = 18, .width = 70, .height = 24 }, "", &pixelSize, 1, 8, false);

    if (pixelSize != prevPixelSize) {
        prevPixelSize = pixelSize;

        tilesWindow.setSize(Consts.TILES_PER_LINE * 8 * pixelSize, Consts.TILES_LINES * 8 * pixelSize);
    }

    rl.drawTextEx(font, "Tiles in editor:", .{ .x = 86, .y = 6 }, 12, 0, lineColor);

    _ = rg.guiComboBox(.{ .x = 86, .y = 18, .width = 100, .height = 24 }, "1;4;9;16", &numEditorTiles);

    if (numEditorTiles != prevNumEditorTiles) {
        prevNumEditorTiles = numEditorTiles;
    }
}

pub fn main() anyerror!u8 {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator: std.mem.Allocator = gpa.allocator();

    rl.setConfigFlags(.{ .window_resizable = true });

    rl.initWindow(1280, 720, "Startile");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    rg.guiLoadStyle("resources/style_jungle.rgs");

    font = try rl.loadFontFromMemory(".ttf", Consts.FONT_DATA, 20, null);
    defer rl.unloadFont(font);

    rg.guiSetFont(font);

    const backgroundColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.background_color))));
    var mouseCell: rl.Vector2 = .{ .x = 0, .y = 0 };

    tilesWindow = try fw.GuiFloatWindow.init(
        gpa_allocator,
        50,
        50,
        Consts.TILES_PER_LINE * 8 * pixelSize,
        Consts.TILES_LINES * 8 * pixelSize,
        "Tiles",
        true,
        false,
    );
    defer tilesWindow.deinit();

    try tilesWindow.addEventListener(&windowEventHandler);

    clipboardWindow = try fw.GuiFloatWindow.init(gpa_allocator, 50, 300, 200, 100, "Clipboard", false, false);
    defer clipboardWindow.deinit();

    try clipboardWindow.addEventListener(&windowEventHandler);

    tileEditorWindow = try fw.GuiFloatWindow.init(gpa_allocator, 50, 550, 200, 100, "Editor", false, false);
    defer tileEditorWindow.deinit();

    try tileEditorWindow.addEventListener(&windowEventHandler);

    tileSelectorWindow = try fw.GuiFloatWindow.init(gpa_allocator, 300, 550, 200, 100, "Active tile", false, false);
    defer tileSelectorWindow.deinit();

    try tileSelectorWindow.addEventListener(&windowEventHandler);

    windows = std.ArrayList(*fw.GuiFloatWindow).init(gpa_allocator);
    defer windows.deinit();

    try windows.append(tilesWindow);
    try windows.append(clipboardWindow);
    try windows.append(tileEditorWindow);
    try windows.append(tileSelectorWindow);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(backgroundColor);

        rl.drawRectangle(50, 50, 200, 200, rl.Color.red);

        _ = rg.guiGrid(.{ .x = 50, .y = 50, .width = 200, .height = 200 }, "GRID", 25, 1, &mouseCell);

        try handleAndDrawWindows();

        try handleAndDrawToolbar();
    }

    return 0;
}
