const std: type = @import("std");
const rl: type = @import("raylib");
const rg: type = @import("raygui");
const fw: type = @import("GuiFloatWindow.zig");

pub const GuiScrollbarOrientation: type = enum {
    horizontal,
    vertical,
};

pub const GuiScrollbarEventName: type = enum {
    scroll_start,
    scroll_moved,
    scroll_end,
};

pub const GuiScrollbarScrollEvent: type = struct {
    window: *fw.GuiFloatWindow,
    scrollbar: *GuiScrollbar,
    value: f32,
};

pub const GuiScrollbarEvent = union(GuiScrollbarEventName) {
    scroll_start: GuiScrollbarScrollEvent,
    scroll_moved: GuiScrollbarScrollEvent,
    scroll_end: GuiScrollbarScrollEvent,
};

pub const GuiScrollbarCallback: type = *const fn (arguments: GuiScrollbarEvent) void;

pub const GuiScrollbar: type = struct {
    parent: *fw.GuiFloatWindow,
    orientation: GuiScrollbarOrientation,
    rect: rl.Rectangle,
    size: i32,
    halfSize: i32,
    scrolling: bool,
    value: f32,
    listeners: std.ArrayList(GuiScrollbarCallback),

    pub fn init(parent: *fw.GuiFloatWindow, x: i32, y: i32, width: i32, height: i32, size: i32, orientation: GuiScrollbarOrientation) anyerror!GuiScrollbar {
        return .{
            .orientation = orientation,
            .parent = parent,
            .rect = .{
                .x = @as(f32, @floatFromInt(x)),
                .y = @as(f32, @floatFromInt(y)),
                .width = @as(f32, @floatFromInt(width)),
                .height = @as(f32, @floatFromInt(height)),
            },
            .size = size,
            .halfSize = @divFloor(size, 2),
            .scrolling = false,
            .value = 0,
            .listeners = std.ArrayList(GuiScrollbarCallback).init(parent.allocator),
        };
    }

    pub fn deinit(self: *GuiScrollbar) void {
        self.listeners.deinit();
    }

    pub fn addEventListener(self: *GuiScrollbar, callback: GuiScrollbarCallback) anyerror!void {
        try self.listeners.append(callback);
    }

    pub fn emit(self: *GuiScrollbar, event: GuiScrollbarEvent) void {
        for (self.listeners.items) |f| {
            f(event);
        }
    }

    pub fn setSize(self: *GuiScrollbar, size: i32) void {
        self.size = size;
        self.halfSize = @divFloor(size, 2);
    }

    pub fn update(self: *GuiScrollbar) bool {
        var handled: bool = false;
        const mouse: rl.Vector2 = rl.getMousePosition();

        if (rl.isMouseButtonPressed(.left) and rl.checkCollisionPointRec(mouse, self.rect)) {
            self.scrolling = true;

            handled = true;

            self.emit(
                .{
                    .scroll_start = .{
                        .window = self.parent,
                        .scrollbar = self,
                        .value = self.value,
                    },
                },
            );
        }

        handleScrolling: {
            if (!self.scrolling) {
                break :handleScrolling;
            }

            handled = true;

            if (rl.isMouseButtonReleased(.left)) {
                self.scrolling = false;

                self.emit(
                    .{
                        .scroll_end = .{
                            .window = self.parent,
                            .scrollbar = self,
                            .value = self.value,
                        },
                    },
                );

                break :handleScrolling;
            }

            const oldValue: f32 = self.value;

            if (self.orientation == .vertical) {
                self.value = std.math.clamp((mouse.y - self.rect.y - @as(f32, @floatFromInt(self.halfSize))) / (self.rect.height - @as(f32, @floatFromInt(self.size))), 0, 1);
            } else {
                self.value = std.math.clamp((mouse.x - self.rect.x - @as(f32, @floatFromInt(self.halfSize))) / (self.rect.width - @as(f32, @floatFromInt(self.size))), 0, 1);
            }

            if (self.value != oldValue) {
                self.emit(
                    .{
                        .scroll_moved = .{
                            .window = self.parent,
                            .scrollbar = self,
                            .value = self.value,
                        },
                    },
                );
            }
        }

        return handled;
    }

    pub fn draw(self: *GuiScrollbar) void {
        const background = rl.Color.fromInt(@as(u32, @bitCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiDefaultProperty.background_color))));
        var foreground = rl.Color.fromInt(@as(u32, @bitCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.base_color_normal))));

        rl.drawRectangleRec(self.rect, background);

        var x: i32 = 0;
        var y: i32 = 0;
        var width: i32 = 0;
        var height: i32 = 0;

        if (self.orientation == .vertical) {
            x = @as(i32, @intFromFloat(self.rect.x));
            y = @as(i32, @intFromFloat(self.rect.y + (self.rect.height - @as(f32, @floatFromInt(self.size))) * self.value));
            width = @as(i32, @intFromFloat(self.rect.width));
            height = self.size;
        } else {
            x = @as(i32, @intFromFloat(self.rect.x + (self.rect.width - @as(f32, @floatFromInt(self.size))) * self.value));
            y = @as(i32, @intFromFloat(self.rect.y));
            width = self.size;
            height = @as(i32, @intFromFloat(self.rect.height));
        }

        if (self.scrolling) {
            foreground = rl.Color.fromInt(@as(u32, @bitCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.base_color_pressed))));
        } else if (rl.checkCollisionPointRec(rl.getMousePosition(), self.rect)) {
            foreground = rl.Color.fromInt(@as(u32, @bitCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.base_color_focused))));
        }

        rl.drawRectangle(x, y, width, height, foreground);
    }
};
