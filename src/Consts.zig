pub const FONT_DATA = @embedFile("embed/firacodebold.ttf");

pub const TOOLBAR_HEIGHT: i32 = 48;
pub const TOOLBAR_ITEM_HEIGHT: i32 = 32;
pub const TOOLBAR_PADDING: i32 = @divFloor(TOOLBAR_HEIGHT - TOOLBAR_ITEM_HEIGHT, 2);

pub const TILES_PER_LINE: i32 = 16;
pub const TILES_LINES: i32 = 32;

pub fn toolbarPaddingForSize(size: i32) i32 {
    return @divFloor(TOOLBAR_HEIGHT - size, 2);
}
