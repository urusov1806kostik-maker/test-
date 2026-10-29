package dev.nyxveravisuals.hud;

import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * HUD element drawn on the shared NyxveraVisuals surface. Every element gets the same style options, so the
 * whole HUD stays visually consistent while remaining configurable per element.
 */
public abstract class PanelHudModule extends HudModule {
	public enum Style {
		SOLID,
		GLASS,
		MINIMAL
	}

	protected static final float PADDING = 5;
	protected static final float TEXT = DesignTokens.FONT_SMALL;

	protected final ModeSetting<Style> style;
	protected final NumberSetting opacity;
	protected final BooleanSetting accentLine;

	protected PanelHudModule(String id, Category category, boolean enabledByDefault, HudAnchor anchor, float offsetX, float offsetY) {
		super(id, category, enabledByDefault, anchor, offsetX, offsetY);
		this.style = settings().add(new ModeSetting<>("hud_style", Style.SOLID));
		this.opacity = settings().add(new NumberSetting("background_opacity", 0.85, 0.0, 1.0, 0.05)).visibleWhen(() -> style.get() != Style.MINIMAL);
		this.accentLine = settings().add(new BooleanSetting("accent_line", true)).visibleWhen(() -> style.get() != Style.MINIMAL);
	}

	/** Draws the element background for a {@code width x height} box at the local origin. */
	protected final void panel(HudContext context, float width, float height) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float radius = DesignTokens.RADIUS_M;
		switch (style.get()) {
			case MINIMAL -> {
				return;
			}
			case GLASS -> {
				int fill = ColorUtil.withAlpha(ColorUtil.shade(theme.panel(), 0.06f), Math.round(150 * opacity.getFloat()));
				renderer.shadow(0, 1, width, height, radius, 8, ColorUtil.withAlpha(0, Math.round(70 * opacity.getFloat())));
				renderer.rounded(0, 0, width, height, radius, fill);
				renderer.outline(0, 0, width, height, radius, 1, ColorUtil.withAlpha(0xFFFFFFFF, Math.round(28 * opacity.getFloat())));
			}
			default -> {
				int fill = ColorUtil.withAlpha(theme.panel(), Math.round(255 * opacity.getFloat()));
				renderer.shadow(0, 1, width, height, radius, 8, ColorUtil.withAlpha(0, Math.round(100 * opacity.getFloat())));
				renderer.rounded(0, 0, width, height, radius, fill);
				renderer.outline(0, 0, width, height, radius, 1, ColorUtil.withAlpha(theme.border(), Math.round(255 * opacity.getFloat())));
			}
		}
		if (accentLine.get()) {
			renderer.gradientVertical(0, radius * 0.6f, 1.6f, height - radius * 1.2f, 0.8f, theme.accent(), theme.accentSecondary());
		}
	}

	protected final boolean textShadow() {
		return style.get() == Style.MINIMAL;
	}

	protected final void text(HudContext context, String value, float x, float y, int color) {
		context.renderer().text(value, x, y, TEXT, color, FontManager.Weight.MEDIUM, textShadow());
	}

	protected final void bold(HudContext context, String value, float x, float y, int color) {
		context.renderer().text(value, x, y, TEXT, color, FontManager.Weight.SEMIBOLD, textShadow());
	}

	protected final float width(HudContext context, String value) {
		return context.renderer().textWidth(value, TEXT);
	}

	protected final float boldWidth(HudContext context, String value) {
		return context.renderer().textWidth(value, TEXT, FontManager.Weight.SEMIBOLD);
	}

	/** Height of a single text line inside a panel. */
	protected final float lineHeight(HudContext context) {
		return context.renderer().lineHeight(TEXT);
	}
}
