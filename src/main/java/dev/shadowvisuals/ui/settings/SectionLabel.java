package dev.shadowvisuals.ui.settings;

import java.util.Locale;

import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.ui.component.Component;

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
