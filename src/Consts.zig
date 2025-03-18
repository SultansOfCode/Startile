pub const FONT_DATA = @embedFile("embed/firacodebold.ttf");

pub const TOOLBAR_HEIGHT: i32 = 64;
pub const TOOLBAR_ITEM_HEIGHT: i32 = 32;
pub const TOOLBAR_PADDING: i32 = @divFloor(TOOLBAR_HEIGHT - TOOLBAR_ITEM_HEIGHT, 2);

pub const TILES_PER_LINE: i32 = 16;
pub const TILES_LINES: i32 = 24;

pub const TILES_PIXEL_SIZE_MIN: i32 = 1;
pub const TILES_PIXEL_SIZE_MAX: i32 = 8;
pub const TILES_PIXEL_SIZE_DEFAULT: i32 = 3;

pub const CLIPBOARD_PIXEL_SIZE_MIN: i32 = 1;
pub const CLIPBOARD_PIXEL_SIZE_MAX: i32 = 8;
pub const CLIPBOARD_PIXEL_SIZE_DEFAULT: i32 = 3;

pub const EDITOR_PIXEL_SIZE_MULTIPLIER: i32 = 4;
pub const EDITOR_PIXEL_SIZE_MIN: i32 = 1 * EDITOR_PIXEL_SIZE_MULTIPLIER;
pub const EDITOR_PIXEL_SIZE_MAX: i32 = 8 * EDITOR_PIXEL_SIZE_MULTIPLIER;
pub const EDITOR_PIXEL_SIZE_DEFAULT: i32 = 3 * EDITOR_PIXEL_SIZE_MULTIPLIER;

pub const EDITOR_SQUARE_SIZE_MIN: i32 = 1;
pub const EDITOR_SQUARE_SIZE_MAX: i32 = 4;
pub const EDITOR_SQUARE_SIZE_DEFAULT: i32 = 2;

pub const SELECTOR_BUTTON_SIZE: i32 = 24;

pub const PALLETE_AREA_SIZE: i32 = 192;

pub const PixelMode: type = enum {
    one_bpp,
    two_bpp_nes,
    two_bpp_virtual_boy,
    two_bpp_neo_geo_pocket,
    two_bpp_gb_gbc,
    three_bpp_snes,
    four_bpp_sms_gg_wsc,
    four_bpp_genesis,
    four_bpp_snes,
    four_bpp_gba,
    eight_bpp_snes,
    eight_bpp_snes_mode7_gba,
};
