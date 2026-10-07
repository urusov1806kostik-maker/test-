package dev.shadowvisuals.ui.component;

import java.util.List;
import java.util.function.IntConsumer;

import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.core.UiSounds;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.util.ColorUtil;

/** Segmented tab bar with a sliding selection pill. */
public final class Tabs extends Component {
	private final List<String> labelKeys;
	private final IntConsumer onSelect;
	private final SmoothValue indicator = new SmoothValue(0f, 16f);
	private int selected;

	public Tabs(List<String> labelKeys, IntConsumer onSelect) {
		this.labelKeys = labelKeys;
		this.onSelect = onSelect;
		setBounds(0, 0, 160, DesignTokens.CONTROL_HEIGHT + 4);
	}

	public int selected() {
		return selected;
	}

	public void select(int index) {
		if (index >= 0 && index < labelKeys.size()) {
			selected = index;
		}
	}

	private float tabWidth() {
		return (width - 4) / labelKeys.size();
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_M, ColorUtil.shade(theme.background(), 0.02f));
		renderer.outline(x, y, width, height, DesignTokens.RADIUS_M, 1, theme.border());
		indicator.setTarget(selected);
		float tab = tabWidth();
		float pillX = x + 2 + indicator.get() * tab;
		renderer.rounded(pillX, y + 2, tab, height - 4, DesignTokens.RADIUS_S, ColorUtil.shade(theme.card(), 0.05f));
		renderer.outline(pillX, y + 2, tab, height - 4, DesignTokens.RADIUS_S, 1, theme.accentMuted(80));
		float size = context.text(DesignTokens.FONT_SMALL);
		for (int i = 0; i < labelKeys.size(); i++) {
			float tabX = x + 2 + i * tab;
			boolean tabHovered = mouseY >= y && mouseY < y + height && mouseX >= tabX && mouseX < tabX + tab;
			int color = i == selected ? theme.textPrimary() : tabHovered ? ColorUtil.lerp(theme.textSecondary(), theme.textPrimary(), 0.5f) : theme.textSecondary();
			String text = renderer.ellipsize(context.tr(labelKeys.get(i)), size, FontManager.Weight.SEMIBOLD, tab - 6);
			renderer.textMiddle(text, tabX + tab / 2f, y + height / 2f, size, color, FontManager.Weight.SEMIBOLD, Renderer2D.Align.CENTER);
		}
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0 || !contains(mouseX, mouseY)) {
			return false;
		}
		int index = Math.min(labelKeys.size() - 1, (int) ((mouseX - x - 2) / tabWidth()));
		if (index != selected) {
			selected = index;
			context.sounds().play(UiSounds.Kind.CLICK);
			onSelect.accept(index);
		}
		return true;
	}
}
