package dev.nyxveravisuals.ui;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.core.UiSounds;
import dev.nyxveravisuals.i18n.Localization;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.overlay.OverlayManager;

/**
 * Shared state for one screen's component tree: rendering, theme, translations, keyboard focus, overlays and
 * tooltips. Logical coordinates are GUI units divided by {@link #scale()}.
 */
public final class UiContext {
	private final NyxveraClient client;
	private final OverlayManager overlays = new OverlayManager();
	private final TooltipManager tooltips = new TooltipManager();
	private Component focused;
	private float scale = 1f;
	private float width;
	private float height;

	public UiContext(NyxveraClient client) {
		this.client = client;
	}

	public NyxveraClient client() {
		return client;
	}

	public Renderer2D renderer() {
		return client.renderer();
	}

	public ThemeManager theme() {
		return client.theme();
	}

	public Localization i18n() {
		return client.i18n();
	}

	public String tr(String key) {
		return client.i18n().tr(key);
	}

	public String tr(String key, Object... args) {
		return client.i18n().tr(key, args);
	}

	public UiSounds sounds() {
		return client.sounds();
	}

	public OverlayManager overlays() {
		return overlays;
	}

	public TooltipManager tooltips() {
		return tooltips;
	}

	/** Logical-to-GUI scale applied by the screen (user UI scale and fit-to-window). */
	public float scale() {
		return scale;
	}

	public float width() {
		return width;
	}

	public float height() {
		return height;
	}

	public void setViewport(float newScale, float logicalWidth, float logicalHeight) {
		this.scale = newScale;
		this.width = logicalWidth;
		this.height = logicalHeight;
	}

	/** Text size multiplied by the accessibility text scale. */
	public float text(float size) {
		return size * client.settings().textScale.getFloat();
	}

	public Component focused() {
		return focused;
	}

	public boolean isFocused(Component component) {
		return focused == component;
	}

	public void focus(Component component) {
		if (focused == component) {
			return;
		}
		Component previous = focused;
		focused = component;
		if (previous != null) {
			previous.onFocusLost(this);
		}
	}

	public void clearFocus() {
		focus(null);
	}
}
