package dev.shadowvisuals.theme;

/**
 * Every size, spacing, radius and duration used by Shadow Visuals UI, in logical GUI units (before the user
 * UI scale is applied). Components read these instead of hard-coding numbers.
 */
public final class DesignTokens {
	private DesignTokens() {
	}

	// Spacing scale
	public static final float SPACE_XXS = 2;
	public static final float SPACE_XS = 4;
	public static final float SPACE_S = 6;
	public static final float SPACE_M = 8;
	public static final float SPACE_L = 12;
	public static final float SPACE_XL = 16;
	public static final float SPACE_XXL = 24;

	// Corner radii
	public static final float RADIUS_XS = 2;
	public static final float RADIUS_S = 4;
	public static final float RADIUS_M = 6;
	public static final float RADIUS_L = 9;
	public static final float RADIUS_XL = 12;
	public static final float RADIUS_PILL = 999;

	public static final float BORDER_WIDTH = 1;

	// Typography (font size in GUI units; vanilla text is 9 units tall)
	public static final float FONT_CAPTION = 6.5f;
	public static final float FONT_SMALL = 7.5f;
	public static final float FONT_BODY = 8.5f;
	public static final float FONT_TITLE = 10f;
	public static final float FONT_HEADING = 12f;

	public static final float ICON_SMALL = 8;
	public static final float ICON_MEDIUM = 10;
	public static final float ICON_LARGE = 14;

	// Component metrics
	public static final float ROW_HEIGHT = 18;
	public static final float CONTROL_HEIGHT = 14;
	public static final float TOGGLE_WIDTH = 20;
	public static final float TOGGLE_HEIGHT = 11;
	public static final float SLIDER_TRACK = 3;
	public static final float SLIDER_KNOB = 8;
	public static final float SCROLLBAR_WIDTH = 3;
	public static final float CARD_HEIGHT = 44;
	public static final float CARD_MIN_WIDTH = 150;
	public static final float SIDEBAR_WIDTH = 108;
	public static final float HEADER_HEIGHT = 30;
	public static final float PANEL_MAX_WIDTH = 560;
	public static final float PANEL_MAX_HEIGHT = 360;
	public static final float SETTINGS_PANEL_WIDTH = 190;
	public static final float POPUP_MIN_WIDTH = 120;
	public static final float TOOLTIP_MAX_WIDTH = 170;
	public static final float SHADOW_SOFTNESS = 14;

	// Motion (seconds)
	public static final float DURATION_INSTANT = 0.08f;
	public static final float DURATION_HOVER = 0.12f;
	public static final float DURATION_TOGGLE = 0.18f;
	public static final float DURATION_PANEL = 0.24f;
	public static final float DURATION_SCREEN = 0.22f;
	public static final float DURATION_NOTIFICATION = 0.28f;
	public static final float TOOLTIP_DELAY = 0.45f;
	public static final float SCROLL_SMOOTHING = 18f;
}
