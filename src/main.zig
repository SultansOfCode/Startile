const std: type = @import("std");
const rl: type = @import("raylib");
const rg: type = @import("raygui");
const fw: type = @import("GuiFloatWindow.zig");
const sb: type = @import("GuiScrollbar.zig");

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

pub fn main() anyerror!u8 {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator: std.mem.Allocator = gpa.allocator();

    rl.initWindow(1280, 720, "Startile");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    rg.guiLoadStyle("resources/style_jungle.rgs");

    const backgroundColor: rl.Color = rl.Color.fromInt(@as(u32, @intCast(rg.guiGetStyle(.default, rg.GuiDefaultProperty.background_color))));
    var mouseCell: rl.Vector2 = .{ .x = 0, .y = 0 };

    var w1 = try fw.GuiFloatWindow.init(gpa_allocator, 50, 50, 200, 100, "Window 1", true, false);
    defer w1.deinit();
    try w1.addEventListener(&windowEventHandler);

    var w2 = try fw.GuiFloatWindow.init(gpa_allocator, 50, 300, 200, 100, "Window 2", false, true);
    defer w2.deinit();
    try w2.addEventListener(&windowEventHandler);

    var w3 = try fw.GuiFloatWindow.init(gpa_allocator, 50, 550, 200, 100, "Window 3", true, true);
    defer w3.deinit();
    try w3.addEventListener(&windowEventHandler);

    var windows: std.ArrayList(*fw.GuiFloatWindow) = std.ArrayList(*fw.GuiFloatWindow).init(gpa_allocator);
    defer windows.deinit();

    try windows.append(w1);
    try windows.append(w2);
    try windows.append(w3);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(backgroundColor);

        rl.drawRectangle(50, 50, 200, 200, rl.Color.red);

        _ = rg.guiGrid(.{ .x = 50, .y = 50, .width = 200, .height = 200 }, "GRID", 25, 1, &mouseCell);

        if (windows.items.len > 0) {
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
    }

    return 0;
}
