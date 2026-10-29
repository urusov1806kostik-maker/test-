package dev.nyxveravisuals.ui.component;

import dev.nyxveravisuals.core.UiSounds;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.util.ColorUtil;

/** Button with optional icon. Styles cover primary actions, neutral actions, destructive actions and icon-only. */
public final class Button extends Component {
	public enum Style {
		PRIMARY,
		SECONDARY,
		DANGER,
		GHOST
	}

	private final String labelKey;
	private final Icon icon;
	private final Style style;
	private final Runnable action;
	private String tooltipKey;
	private boolean enabled = true;

	public Button(String labelKey, Icon icon, Style style, Runnable action) {
		this.labelKey = labelKey;
		this.icon = icon;
		this.style = style;
		this.action = action;
		setBounds(0, 0, 60, DesignTokens.CONTROL_HEIGHT + 2);
	}

	public static Button icon(Icon icon, String tooltipKey, Runnable action) {
		Button button = new Button(null, icon, Style.GHOST, action);
		button.tooltipKey = tooltipKey;
		button.setBounds(0, 0, DesignTokens.CONTROL_HEIGHT + 2, DesignTokens.CONTROL_HEIGHT + 2);
		return button;
	}

	public Button tooltip(String key) {
		this.tooltipKey = key;
		return this;
	}

	public void setEnabled(boolean value) {
		this.enabled = value;
	}

	/** Width that fits label and icon. */
	public float preferredWidth(UiContext context) {
		float textWidth = labelKey == null ? 0 : context.renderer().textWidth(context.tr(labelKey), context.text(DesignTokens.FONT_SMALL), FontManager.Weight.SEMIBOLD);
		float iconWidth = icon == null ? 0 : DesignTokens.ICON_SMALL + (labelKey == null ? 0 : DesignTokens.SPACE_XS);
		return Math.max(height, textWidth + iconWidth + DesignTokens.SPACE_L * 2);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float hover = enabled ? hover() : 0f;
		int fill;
		int text;
		int border = 0;
		switch (style) {
			case PRIMARY -> {
				fill = ColorUtil.shade(theme.accent(), hover * 0.08f);
				text = ColorUtil.readableTextOn(theme.accent());
			}
			case DANGER -> {
				fill = ColorUtil.withAlpha(theme.error(), 40 + Math.round(hover * 40));
				text = ColorUtil.shade(theme.error(), 0.25f);
				border = ColorUtil.withAlpha(theme.error(), 90);
			}
			case GHOST -> {
				fill = ColorUtil.withAlpha(theme.textPrimary(), Math.round(hover * 18));
				text = ColorUtil.lerp(theme.textSecondary(), theme.textPrimary(), hover);
			}
			default -> {
				fill = ColorUtil.shade(theme.card(), 0.03f + hover * 0.04f);
				text = theme.textPrimary();
				border = theme.border();
			}
		}
		if (!enabled) {
			fill = ColorUtil.fade(fill, 0.5f);
			text = theme.textDisabled();
		}
		if (style == Style.PRIMARY) {
			renderer.gradientHorizontal(x, y, width, height, DesignTokens.RADIUS_M, fill, ColorUtil.lerp(fill, theme.accentSecondary(), 0.45f));
		} else {
			renderer.rounded(x, y, width, height, DesignTokens.RADIUS_M, fill);
		}
		if (ColorUtil.alpha(border) > 0) {
			renderer.outline(x, y, width, height, DesignTokens.RADIUS_M, 1, border);
		}
		float size = context.text(DesignTokens.FONT_SMALL);
		String label = labelKey == null ? null : context.tr(labelKey);
		float labelWidth = label == null ? 0 : renderer.textWidth(label, size, FontManager.Weight.SEMIBOLD);
		float iconSize = labelKey == null ? Math.min(width, height) * 0.62f : DesignTokens.ICON_SMALL;
		float gap = icon != null && label != null ? DesignTokens.SPACE_XS : 0;
		float contentWidth = (icon != null ? iconSize : 0) + gap + labelWidth;
		float cursor = x + (width - contentWidth) / 2f;
		if (icon != null) {
			icon.draw(renderer, cursor, y + (height - iconSize) / 2f, iconSize, text);
			cursor += iconSize + gap;
		}
		if (label != null) {
			renderer.textMiddle(label, cursor, y + height / 2f, size, text, FontManager.Weight.SEMIBOLD, Renderer2D.Align.LEFT);
		}
	}

	@Override
	protected String tooltip(UiContext context) {
		return tooltipKey == null ? null : context.tr(tooltipKey);
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0 || !enabled || !contains(mouseX, mouseY)) {
			return false;
		}
		context.sounds().play(UiSounds.Kind.CLICK);
		action.run();
		return true;
	}
}
