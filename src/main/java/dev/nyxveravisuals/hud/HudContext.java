package dev.nyxveravisuals.hud;

import dev.nyxveravisuals.i18n.Localization;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.theme.ThemeManager;

/**
 * Everything a HUD element needs to draw one frame.
 *
 * @param editing   true inside the HUD editor: elements show preview data when they have no live content
 * @param privacy   recording-mode filter: elements must hide what it marks as private
 */
public record HudContext(Renderer2D renderer, ThemeManager theme, Localization i18n, float partialTick,
	float screenWidth, float screenHeight, boolean editing, Privacy privacy) {

	/** What recording mode currently hides. */
	public record Privacy(boolean hideName, boolean hideCoordinates, boolean hideServer, boolean hidePrivateHud) {
		public static final Privacy NONE = new Privacy(false, false, false, false);
	}

	public String tr(String key) {
		return i18n.tr(key);
	}
}
