package dev.nyxveravisuals.ui.settings;

import java.util.Locale;

import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Component;

/** Non-interactive section title with a divider line. */
public final class SectionLabel extends Component {
	private final String key;

	public SectionLabel(String key) {
		this.key = key;
	}

	@Override
	public float preferredHeight(UiContext context, float availableWidth) {
		return 18;
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float size = context.text(DesignTokens.FONT_CAPTION);
		String title = context.tr(key).toUpperCase(Locale.ROOT);
		float cy = y + height / 2f + 1;
		renderer.textMiddle(title, x, cy, size, theme.textSecondary(), FontManager.Weight.SEMIBOLD, Renderer2D.Align.LEFT);
		float end = x + renderer.textWidth(title, size, FontManager.Weight.SEMIBOLD) + 6;
		renderer.rect(end, cy, Math.max(0, x + width - end), 1, theme.border());
	}
}
