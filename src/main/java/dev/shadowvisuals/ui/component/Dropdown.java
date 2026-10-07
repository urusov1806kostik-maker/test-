package dev.shadowvisuals.ui.component;

import java.util.List;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.function.Supplier;

import dev.shadowvisuals.core.UiSounds;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.ui.overlay.ListOverlay;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Compact select box. Single mode closes after a pick; multi mode keeps the list open and shows checks.
 * The option list is an overlay, so it renders above everything and blocks clicks to widgets beneath.
 */
public final class Dropdown<T> extends Component {
	private final Supplier<List<T>> options;
	private final Function<T, String> label;
	private final Predicate<T> selected;
	private final java.util.function.Consumer<T> onPick;
	private final Supplier<String> summary;
	private final boolean multi;
	private ListOverlay<T> open;

	private Dropdown(Supplier<List<T>> options, Function<T, String> label, Predicate<T> selected,
		java.util.function.Consumer<T> onPick, Supplier<String> summary, boolean multi) {
		this.options = options;
		this.label = label;
		this.selected = selected;
		this.onPick = onPick;
		this.summary = summary;
		this.multi = multi;
		setBounds(0, 0, 80, DesignTokens.CONTROL_HEIGHT);
	}

	public static <T> Dropdown<T> single(Supplier<List<T>> options, Function<T, String> label, Supplier<T> current,
		java.util.function.Consumer<T> onPick) {
		return new Dropdown<>(options, label, option -> option.equals(current.get()), onPick, () -> label.apply(current.get()), false);
	}

	public static <T> Dropdown<T> multi(Supplier<List<T>> options, Function<T, String> label, Predicate<T> selected,
		java.util.function.Consumer<T> onToggle, Supplier<String> summary) {
		return new Dropdown<>(options, label, selected, onToggle, summary, true);
	}

	public float preferredWidth(UiContext context) {
		float size = context.text(DesignTokens.FONT_SMALL);
		float widest = 0;
		for (T option : options.get()) {
			widest = Math.max(widest, context.renderer().textWidth(label.apply(option), size));
		}
		return Math.min(130, widest + DesignTokens.SPACE_M * 2 + DesignTokens.ICON_SMALL + DesignTokens.SPACE_XS);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		boolean expanded = open != null && !open.isClosing();
		int fill = ColorUtil.shade(theme.background(), 0.03f + hover() * 0.03f);
		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_S, fill);
		renderer.outline(x, y, width, height, DesignTokens.RADIUS_S, 1, expanded ? theme.accentMuted(170) : theme.border());
		float size = context.text(DesignTokens.FONT_SMALL);
		float iconSize = DesignTokens.ICON_SMALL - 1;
		String text = renderer.ellipsize(summary.get(), size, FontManager.Weight.MEDIUM, width - DesignTokens.SPACE_M * 2 - iconSize);
		renderer.textMiddle(text, x + DesignTokens.SPACE_S, y + height / 2f, size, theme.textPrimary());
		renderer.push();
		float iconX = x + width - DesignTokens.SPACE_S - iconSize;
		float iconY = y + (height - iconSize) / 2f;
		if (expanded) {
			renderer.translate(iconX + iconSize / 2f, iconY + iconSize / 2f);
			renderer.pose().rotate((float) Math.PI);
			renderer.translate(-(iconX + iconSize / 2f), -(iconY + iconSize / 2f));
		}
		Icon.CHEVRON_DOWN.draw(renderer, iconX, iconY, iconSize, theme.textSecondary());
		renderer.pop();
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0 || !contains(mouseX, mouseY)) {
			return false;
		}
		context.sounds().play(UiSounds.Kind.CLICK);
		open = new ListOverlay<>(this, options, label, selected, option -> {
			onPick.accept(option);
			context.sounds().play(UiSounds.Kind.CLICK);
		}, multi);
		context.overlays().open(open);
		return true;
	}
}
