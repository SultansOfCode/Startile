const std: type = @import("std");
const rl: type = @import("raylib");
const rg: type = @import("raygui");
const sb: type = @import("GuiScrollbar.zig");
const Consts: type = @import("Consts.zig");

pub const GuiFloatWindowEventName: type = enum {
    drag_start,
    drag_moved,
    drag_end,
    left_click_start,
    left_click_moved,
    left_click_end,
    middle_click_start,
    middle_click_moved,
    middle_click_end,
    right_click_start,
    right_click_moved,
    right_click_end,
    scroll_vertical_start,
    scroll_vertical_moved,
    scroll_vertical_end,
    scroll_horizontal_start,
    scroll_horizontal_moved,
    scroll_horizontal_end,
};

pub const GuiFloatWindowDragEvent: type = struct {
    window: *GuiFloatWindow,
    windowPosition: rl.Vector2,
};

pub const GuiFloatWindowMouseEvent: type = struct {
    window: *GuiFloatWindow,
    mousePosition: rl.Vector2,
};

pub const GuiFloatWindowScrollbarEvent: type = struct {
    window: *GuiFloatWindow,
    scrollbar: *sb.GuiScrollbar,
    value: f32,
};

pub const GuiFloatWindowEvent: type = union(GuiFloatWindowEventName) {
    drag_start: GuiFloatWindowDragEvent,
    drag_moved: GuiFloatWindowDragEvent,
    drag_end: GuiFloatWindowDragEvent,
    left_click_start: GuiFloatWindowMouseEvent,
    left_click_moved: GuiFloatWindowMouseEvent,
    left_click_end: GuiFloatWindowMouseEvent,
    middle_click_start: GuiFloatWindowMouseEvent,
    middle_click_moved: GuiFloatWindowMouseEvent,
    middle_click_end: GuiFloatWindowMouseEvent,
    right_click_start: GuiFloatWindowMouseEvent,
    right_click_moved: GuiFloatWindowMouseEvent,
    right_click_end: GuiFloatWindowMouseEvent,
    scroll_vertical_start: GuiFloatWindowScrollbarEvent,
    scroll_vertical_moved: GuiFloatWindowScrollbarEvent,
    scroll_vertical_end: GuiFloatWindowScrollbarEvent,
    scroll_horizontal_start: GuiFloatWindowScrollbarEvent,
    scroll_horizontal_moved: GuiFloatWindowScrollbarEvent,
    scroll_horizontal_end: GuiFloatWindowScrollbarEvent,
};

pub const GuiFloatWindowCallback: type = *const fn (event: GuiFloatWindowEvent) void;

pub const GuiFloatWindow: type = struct {
    title: [*:0]const u8,
    headerRect: rl.Rectangle,
    bodyRect: rl.Rectangle,
    scrollbarHorizontalRect: rl.Rectangle,
    scrollbarVerticalRect: rl.Rectangle,
    windowRect: rl.Rectangle,
    dragging: bool,
    bodyMouseButton: ?rl.MouseButton,
    bodyMousePosition: ?rl.Vector2,
    scrolling: bool,
    scrollbarVertical: ?sb.GuiScrollbar,
    scrollbarHorizontal: ?sb.GuiScrollbar,
    allocator: std.mem.Allocator,
    listeners: std.ArrayList(GuiFloatWindowCallback),

    pub var BORDER_WIDTH: i32 = 1;
    pub const HEADER_HEIGHT: i32 = 23;
    pub const SCROLLBAR_SIZE: i32 = 16;
    pub const SCROLLBAR_BAR_SCALE: f32 = 0.15;

    pub fn moveBy(self: *GuiFloatWindow, delta: rl.Vector2) void {
        if (delta.x == 0 and delta.y == 0) {
            return;
        }

        self.headerRect.x += delta.x;
        self.headerRect.y += delta.y;

        self.bodyRect.x += delta.x;
        self.bodyRect.y += delta.y;

        if (self.scrollbarVertical) |*scrollbarVertical| {
            self.scrollbarVerticalRect.x += delta.x;
            self.scrollbarVerticalRect.y += delta.y;

            scrollbarVertical.rect.x += delta.x;
            scrollbarVertical.rect.y += delta.y;
        }

        if (self.scrollbarHorizontal) |*scrollbarHorizontal| {
            self.scrollbarHorizontalRect.x += delta.x;
            self.scrollbarHorizontalRect.y += delta.y;

            scrollbarHorizontal.rect.x += delta.x;
            scrollbarHorizontal.rect.y += delta.y;
        }

        self.windowRect.x += delta.x;
        self.windowRect.y += delta.y;
    }

    pub fn setSize(self: *GuiFloatWindow, width: i32, height: i32) void {
        const delta: rl.Vector2 = rl.Vector2.init(
            @as(f32, @floatFromInt(width)) - self.bodyRect.width,
            @as(f32, @floatFromInt(height)) - self.bodyRect.height,
        );

        if (delta.x == 0 and delta.y == 0) {
            return;
        }

        self.headerRect.width += delta.x;

        self.bodyRect.width += delta.x;
        self.bodyRect.height += delta.y;

        self.windowRect.width += delta.x;
        self.windowRect.height += delta.y;

        if (self.scrollbarVertical) |*scrollbarVertical| {
            self.scrollbarVerticalRect.x += delta.x;
            self.scrollbarVerticalRect.height += delta.y;

            scrollbarVertical.rect.x += delta.x;
            scrollbarVertical.rect.height += delta.y;

            scrollbarVertical.setSize(@as(i32, @intFromFloat(scrollbarVertical.rect.height * GuiFloatWindow.SCROLLBAR_BAR_SCALE)));
        }

        if (self.scrollbarHorizontal) |*scrollbarHorizontal| {
            self.scrollbarHorizontalRect.y += delta.y;
            self.scrollbarHorizontalRect.width += delta.x;

            scrollbarHorizontal.rect.y += delta.y;
            scrollbarHorizontal.rect.width += delta.x;

            scrollbarHorizontal.setSize(@as(i32, @intFromFloat(scrollbarHorizontal.rect.width * GuiFloatWindow.SCROLLBAR_BAR_SCALE)));
        }
    }

    pub fn scrollbarEventHandler(event: sb.GuiScrollbarEvent) void {
        switch (event) {
            .scroll_start => |arguments| {
                arguments.window.scrolling = true;

                if (arguments.scrollbar.orientation == .vertical) {
                    arguments.window.emit(
                        .{
                            .scroll_vertical_start = .{
                                .window = arguments.window,
                                .scrollbar = arguments.scrollbar,
                                .value = arguments.value,
                            },
                        },
                    );
                } else {
                    arguments.window.emit(
                        .{
                            .scroll_horizontal_start = .{
                                .window = arguments.window,
                                .scrollbar = arguments.scrollbar,
                                .value = arguments.value,
                            },
                        },
                    );
                }
            },
            .scroll_moved => |arguments| {
                if (arguments.scrollbar.orientation == .vertical) {
                    arguments.window.emit(
                        .{
                            .scroll_vertical_moved = .{
                                .window = arguments.window,
                                .scrollbar = arguments.scrollbar,
                                .value = arguments.value,
                            },
                        },
                    );
                } else {
                    arguments.window.emit(
                        .{
                            .scroll_horizontal_moved = .{
                                .window = arguments.window,
                                .scrollbar = arguments.scrollbar,
                                .value = arguments.value,
                            },
                        },
                    );
                }
            },
            .scroll_end => |arguments| {
                arguments.window.scrolling = false;

                if (arguments.scrollbar.orientation == .vertical) {
                    arguments.window.emit(
                        .{
                            .scroll_vertical_end = .{
                                .window = arguments.window,
                                .scrollbar = arguments.scrollbar,
                                .value = arguments.value,
                            },
                        },
                    );
                } else {
                    arguments.window.emit(
                        .{
                            .scroll_horizontal_end = .{
                                .window = arguments.window,
                                .scrollbar = arguments.scrollbar,
                                .value = arguments.value,
                            },
                        },
                    );
                }
            },
        }
    }

    pub fn init(allocator: std.mem.Allocator, x: i32, y: i32, width: i32, height: i32, title: [*:0]const u8, hasScrollbarVertical: bool, hasScrollbarHorizontal: bool) anyerror!*GuiFloatWindow {
        GuiFloatWindow.BORDER_WIDTH = rg.guiGetStyle(rg.GuiControl.default, rg.GuiControlProperty.border_width);

        var fw: *GuiFloatWindow = try allocator.create(GuiFloatWindow);

        fw.title = title;
        fw.headerRect = .{
            .x = @as(f32, @floatFromInt(x)),
            .y = @as(f32, @floatFromInt(y)),
            .width = @as(f32, @floatFromInt(width + 2 * GuiFloatWindow.BORDER_WIDTH + if (hasScrollbarVertical) GuiFloatWindow.SCROLLBAR_SIZE else 0)),
            .height = @as(f32, @floatFromInt(GuiFloatWindow.HEADER_HEIGHT)),
        };
        fw.bodyRect = .{
            .x = @as(f32, @floatFromInt(x + GuiFloatWindow.BORDER_WIDTH)),
            .y = @as(f32, @floatFromInt(y + GuiFloatWindow.HEADER_HEIGHT + GuiFloatWindow.BORDER_WIDTH)),
            .width = @as(f32, @floatFromInt(width)),
            .height = @as(f32, @floatFromInt(height)),
        };
        fw.scrollbarVerticalRect = if (hasScrollbarVertical) .{
            .x = @as(f32, @floatFromInt(x + width + GuiFloatWindow.BORDER_WIDTH)),
            .y = @as(f32, @floatFromInt(y + GuiFloatWindow.HEADER_HEIGHT + GuiFloatWindow.BORDER_WIDTH)),
            .width = @as(f32, @floatFromInt(GuiFloatWindow.SCROLLBAR_SIZE)),
            .height = @as(f32, @floatFromInt(height)),
        } else .{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
        };
        fw.scrollbarHorizontalRect = if (hasScrollbarHorizontal) .{
            .x = @as(f32, @floatFromInt(x + GuiFloatWindow.BORDER_WIDTH)),
            .y = @as(f32, @floatFromInt(y + GuiFloatWindow.HEADER_HEIGHT + height + GuiFloatWindow.BORDER_WIDTH)),
            .width = @as(f32, @floatFromInt(width)),
            .height = @as(f32, @floatFromInt(GuiFloatWindow.SCROLLBAR_SIZE)),
        } else .{
            .x = 0,
            .y = 0,
            .width = 0,
            .height = 0,
        };
        fw.windowRect = .{
            .x = @as(f32, @floatFromInt(x)),
            .y = @as(f32, @floatFromInt(y)),
            .width = @as(f32, @floatFromInt(width + 2 * GuiFloatWindow.BORDER_WIDTH + if (hasScrollbarVertical) GuiFloatWindow.SCROLLBAR_SIZE else 0)),
            .height = @as(f32, @floatFromInt(height + GuiFloatWindow.HEADER_HEIGHT + 2 * GuiFloatWindow.BORDER_WIDTH + if (hasScrollbarHorizontal) GuiFloatWindow.SCROLLBAR_SIZE else 0)),
        };
        fw.dragging = false;
        fw.bodyMouseButton = null;
        fw.bodyMousePosition = null;
        fw.scrolling = false;
        fw.scrollbarVertical = null;
        fw.scrollbarHorizontal = null;
        fw.allocator = allocator;
        fw.listeners = std.ArrayList(GuiFloatWindowCallback).init(allocator);

        if (hasScrollbarVertical) {
            fw.scrollbarVertical = try sb.GuiScrollbar.init(
                fw,
                x + width + GuiFloatWindow.BORDER_WIDTH,
                y + GuiFloatWindow.HEADER_HEIGHT + GuiFloatWindow.BORDER_WIDTH,
                GuiFloatWindow.SCROLLBAR_SIZE,
                height,
                @as(i32, @intFromFloat(@as(f32, @floatFromInt(height)) * GuiFloatWindow.SCROLLBAR_BAR_SCALE)),
                .vertical,
            );

            try fw.scrollbarVertical.?.addEventListener(
                &GuiFloatWindow.scrollbarEventHandler,
            );
        }

        if (hasScrollbarHorizontal) {
            fw.scrollbarHorizontal = try sb.GuiScrollbar.init(
                fw,
                x + GuiFloatWindow.BORDER_WIDTH,
                y + GuiFloatWindow.HEADER_HEIGHT + height + GuiFloatWindow.BORDER_WIDTH,
                width,
                GuiFloatWindow.SCROLLBAR_SIZE,
                @as(i32, @intFromFloat(@as(f32, @floatFromInt(width)) * GuiFloatWindow.SCROLLBAR_BAR_SCALE)),
                .horizontal,
            );

            try fw.scrollbarHorizontal.?.addEventListener(
                &GuiFloatWindow.scrollbarEventHandler,
            );
        }

        return fw;
    }

    pub fn deinit(self: *GuiFloatWindow) void {
        if (self.scrollbarVertical) |*scrollbarVertical| {
            scrollbarVertical.deinit();
        }

        if (self.scrollbarHorizontal) |*scrollbarHorizontal| {
            scrollbarHorizontal.deinit();
        }

        self.listeners.deinit();

        self.allocator.destroy(self);
    }

    pub fn addEventListener(self: *GuiFloatWindow, callback: GuiFloatWindowCallback) anyerror!void {
        try self.listeners.append(callback);
    }

    pub fn emit(self: *GuiFloatWindow, event: GuiFloatWindowEvent) void {
        for (self.listeners.items) |f| {
            f(event);
        }
    }

    pub fn update(self: *GuiFloatWindow) bool {
        const mousePosition: rl.Vector2 = rl.getMousePosition();

        var mouseButton: ?rl.MouseButton = null;
        var handled: bool = false;

        if (!rg.guiIsLocked()) {
            if (rl.isMouseButtonPressed(.left)) {
                mouseButton = .left;
            } else if (rl.isMouseButtonPressed(.middle)) {
                mouseButton = .middle;
            } else if (rl.isMouseButtonPressed(.right)) {
                mouseButton = .right;
            }
        }

        const mousePressed: bool = mouseButton != null;

        if (mousePressed and !self.dragging and self.bodyMouseButton == null and !self.scrolling) {
            if (rl.isMouseButtonPressed(.left) and rl.checkCollisionPointRec(mousePosition, self.headerRect)) {
                self.dragging = true;

                self.emit(
                    .{
                        .drag_start = .{
                            .window = self,
                            .windowPosition = rl.Vector2.init(
                                self.windowRect.x,
                                self.windowRect.y,
                            ),
                        },
                    },
                );
            } else if (mousePressed and rl.checkCollisionPointRec(mousePosition, self.bodyRect)) {
                self.bodyMouseButton = mouseButton;
                self.bodyMousePosition = mousePosition;

                switch (mouseButton.?) {
                    .left => {
                        self.emit(
                            .{
                                .left_click_start = .{
                                    .window = self,
                                    .mousePosition = rl.Vector2.init(
                                        mousePosition.x - self.bodyRect.x,
                                        mousePosition.y - self.bodyRect.y,
                                    ),
                                },
                            },
                        );
                    },
                    .middle => {
                        self.emit(
                            .{
                                .middle_click_start = .{
                                    .window = self,
                                    .mousePosition = rl.Vector2.init(
                                        mousePosition.x - self.bodyRect.x,
                                        mousePosition.y - self.bodyRect.y,
                                    ),
                                },
                            },
                        );
                    },
                    .right => {
                        self.emit(
                            .{
                                .right_click_start = .{
                                    .window = self,
                                    .mousePosition = rl.Vector2.init(
                                        mousePosition.x - self.bodyRect.x,
                                        mousePosition.y - self.bodyRect.y,
                                    ),
                                },
                            },
                        );
                    },
                    else => unreachable,
                }
            }
        }

        handleHeader: {
            if (self.dragging) {
                handled = true;

                if (rl.isMouseButtonReleased(.left)) {
                    self.emit(
                        .{
                            .drag_end = .{
                                .window = self,
                                .windowPosition = rl.Vector2.init(
                                    self.windowRect.x,
                                    self.windowRect.y,
                                ),
                            },
                        },
                    );

                    self.dragging = false;

                    break :handleHeader;
                }

                var delta: rl.Vector2 = rl.getMouseDelta();

                if (delta.x == 0 and delta.y == 0) {
                    break :handleHeader;
                }

                const oldPosition: rl.Vector2 = rl.Vector2.init(self.windowRect.x, self.windowRect.y);

                self.windowRect.x = std.math.clamp(
                    self.windowRect.x + delta.x,
                    -self.windowRect.width + @as(f32, @floatFromInt(GuiFloatWindow.HEADER_HEIGHT)),
                    @as(f32, @floatFromInt(rl.getScreenWidth() - GuiFloatWindow.HEADER_HEIGHT)),
                );

                self.windowRect.y = std.math.clamp(
                    self.windowRect.y + delta.y,
                    @as(f32, @floatFromInt(Consts.TOOLBAR_HEIGHT)),
                    @as(f32, @floatFromInt(rl.getScreenHeight() - GuiFloatWindow.HEADER_HEIGHT)),
                );

                delta.x = self.windowRect.x - oldPosition.x;
                delta.y = self.windowRect.y - oldPosition.y;

                self.headerRect.x += delta.x;
                self.headerRect.y += delta.y;

                self.bodyRect.x += delta.x;
                self.bodyRect.y += delta.y;

                if (self.scrollbarVertical) |*scrollbarVertical| {
                    self.scrollbarVerticalRect.x += delta.x;
                    self.scrollbarVerticalRect.y += delta.y;

                    scrollbarVertical.rect.x += delta.x;
                    scrollbarVertical.rect.y += delta.y;
                }

                if (self.scrollbarHorizontal) |*scrollbarHorizontal| {
                    self.scrollbarHorizontalRect.x += delta.x;
                    self.scrollbarHorizontalRect.y += delta.y;

                    scrollbarHorizontal.rect.x += delta.x;
                    scrollbarHorizontal.rect.y += delta.y;
                }

                self.emit(
                    .{
                        .drag_moved = .{
                            .window = self,
                            .windowPosition = rl.Vector2.init(
                                self.windowRect.x,
                                self.windowRect.y,
                            ),
                        },
                    },
                );
            }
        }

        handleBody: {
            if (self.bodyMouseButton) |bodyMouseButton| {
                handled = true;

                if (rl.isMouseButtonReleased(bodyMouseButton)) {
                    switch (bodyMouseButton) {
                        .left => {
                            self.emit(
                                .{
                                    .left_click_end = .{
                                        .window = self,
                                        .mousePosition = rl.Vector2.init(
                                            mousePosition.x - self.bodyRect.x,
                                            mousePosition.y - self.bodyRect.y,
                                        ),
                                    },
                                },
                            );
                        },
                        .middle => {
                            self.emit(
                                .{
                                    .middle_click_end = .{
                                        .window = self,
                                        .mousePosition = rl.Vector2.init(
                                            mousePosition.x - self.bodyRect.x,
                                            mousePosition.y - self.bodyRect.y,
                                        ),
                                    },
                                },
                            );
                        },
                        .right => {
                            self.emit(
                                .{
                                    .right_click_end = .{
                                        .window = self,
                                        .mousePosition = rl.Vector2.init(
                                            mousePosition.x - self.bodyRect.x,
                                            mousePosition.y - self.bodyRect.y,
                                        ),
                                    },
                                },
                            );
                        },
                        else => unreachable,
                    }

                    self.bodyMouseButton = null;

                    break :handleBody;
                }

                if (!rl.checkCollisionPointRec(mousePosition, self.bodyRect)) {
                    break :handleBody;
                }

                const delta: rl.Vector2 = rl.getMouseDelta();

                if (delta.x == 0 and delta.y == 0) {
                    break :handleBody;
                }

                switch (bodyMouseButton) {
                    .left => {
                        self.emit(
                            .{
                                .left_click_moved = .{
                                    .window = self,
                                    .mousePosition = rl.Vector2.init(
                                        mousePosition.x - self.bodyRect.x,
                                        mousePosition.y - self.bodyRect.y,
                                    ),
                                },
                            },
                        );
                    },
                    .middle => {
                        self.emit(
                            .{
                                .middle_click_moved = .{
                                    .window = self,
                                    .mousePosition = rl.Vector2.init(
                                        mousePosition.x - self.bodyRect.x,
                                        mousePosition.y - self.bodyRect.y,
                                    ),
                                },
                            },
                        );
                    },
                    .right => {
                        self.emit(
                            .{
                                .right_click_moved = .{
                                    .window = self,
                                    .mousePosition = rl.Vector2.init(
                                        mousePosition.x - self.bodyRect.x,
                                        mousePosition.y - self.bodyRect.y,
                                    ),
                                },
                            },
                        );
                    },
                    else => unreachable,
                }
            }
        }

        if (self.scrollbarVertical) |*scrollbarVertical| {
            handled = handled or scrollbarVertical.update();
        }

        if (self.scrollbarHorizontal) |*scrollbarHorizontal| {
            handled = handled or scrollbarHorizontal.update();
        }

        return handled;
    }

    pub fn draw(self: *GuiFloatWindow) void {
        const backgroundColor = rl.Color.fromInt(@as(u32, @bitCast(rg.guiGetStyle(rg.GuiControl.default, rg.GuiDefaultProperty.background_color))));

        _ = rg.guiPanel(self.windowRect, self.title);

        rl.drawRectangleRec(self.bodyRect, backgroundColor);

        if (self.scrollbarVertical) |*scrollbarVertical| {
            scrollbarVertical.draw();
        }

        if (self.scrollbarHorizontal) |*scrollbarHorizontal| {
            scrollbarHorizontal.draw();
        }
    }
};
