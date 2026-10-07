package dev.shadowvisuals.ui.overlay;

import java.util.List;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.function.Supplier;

import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.ui.component.Component;
import dev.shadowvisuals.util.ColorUtil;
import dev.shadowvisuals.util.MathUtil;

/** Option list shown under (or above) its anchor; flips and clamps so it never leaves the screen. */
public final class ListOverlay<T> extends Overlay {
	private static final float ROW = 15;
	private static final float MAX_HEIGHT = 150;

	private final Component anchor;
	private final Supplier<List<T>> options;
	private final Function<T, String> label;
	private final Predicate<T> selected;
	private final Consumer<T> onPick;
	private final boolean multi;
	private final SmoothValue scroll = new SmoothValue(0f, DesignTokens.SCROLL_SMOOTHING);
	private float scrollTarget;
	private boolean above;

	public ListOverlay(Component anchor, Supplier<List<T>> options, Function<T, String> label, Predicate<T> selected,
		Consumer<T> onPick, boolean multi) {
		super(false);
		this.anchor = anchor;
		this.options = options;
		this.label = label;
		this.selected = selected;
		this.onPick = onPick;
		this.multi = multi;
	}

	private float contentHeight() {
		return options.get().size() * ROW + 4;
	}

	@Override
	protected void layout(UiContext context) {
		float listWidth = Math.max(anchor.width(), DesignTokens.POPUP_MIN_WIDTH * 0.75f);
		float size = context.text(DesignTokens.FONT_SMALL);
		for (T option : options.get()) {
			listWidth = Math.max(listWidth, context.renderer().textWidth(label.apply(option), size) + 30);
		}
		float listHeight = Math.min(contentHeight(), MAX_HEIGHT);
		float below = anchor.y() + anchor.height() + 3;
		above = below + listHeight > context.height() - 4 && anchor.y() - listHeight - 3 > 4;
		float top = above ? anchor.y() - listHeight - 3 : Math.min(below, context.height() - listHeight - 4);
		float left = MathUtil.clamp(anchor.x() + anchor.width() - listWidth, 4, context.width() - listWidth - 4);
		if (listWidth <= anchor.width()) {
			left = anchor.x();
		}
		setBounds(left, top, listWidth, listHeight);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float appear = presence();
		renderer.pushAlpha(appear);
		renderer.push();
		renderer.translate(0, (above ? 1 : -1) * (1 - appear) * 4);
		renderer.surface(x, y, width, height, DesignTokens.RADIUS_M, ColorUtil.shade(theme.panel(), 0.02f), theme.border(), theme.shadow(), 12);
		float maxScroll = Math.max(0, contentHeight() - height);
		scrollTarget = MathUtil.clamp(scrollTarget, 0, maxScroll);
		scroll.setTarget(scrollTarget);
		float offset = scroll.get();
		renderer.pushClip(x, y + 1, width, height - 2);
		float size = context.text(DesignTokens.FONT_SMALL);
		List<T> list = options.get();
		for (int i = 0; i < list.size(); i++) {
			float rowY = y + 2 + i * ROW - offset;
			if (rowY + ROW < y || rowY > y + height) {
				continue;
			}
			T option = list.get(i);
			boolean isSelected = selected.test(option);
			boolean rowHovered = mouseX >= x && mouseX < x + width && mouseY >= rowY && mouseY < rowY + ROW && contains(mouseX, mouseY);
			if (rowHovered) {
				renderer.rounded(x + 2, rowY, width - 4, ROW, DesignTokens.RADIUS_S, ColorUtil.withAlpha(theme.textPrimary(), 16));
			}
			float textX = x + DesignTokens.SPACE_S;
			if (multi) {
				float box = 8;
				float boxY = rowY + (ROW - box) / 2f;
				renderer.rounded(textX, boxY, box, box, 2, isSelected ? theme.accent() : ColorUtil.shade(theme.background(), 0.04f));
				renderer.outline(textX, boxY, box, box, 2, 1, isSelected ? theme.accent() : theme.border());
				if (isSelected) {
					Icon.CHECK.draw(renderer, textX + 0.5f, boxY + 0.5f, box - 1, ColorUtil.readableTextOn(theme.accent()));
				}
				textX += box + DesignTokens.SPACE_S;
			}
			int color = isSelected ? theme.textPrimary() : theme.textSecondary();
			renderer.textMiddle(label.apply(option), textX, rowY + ROW / 2f, size, rowHovered ? theme.textPrimary() : color);
			if (!multi && isSelected) {
				Icon.CHECK.draw(renderer, x + width - DesignTokens.SPACE_S - 7, rowY + (ROW - 7) / 2f, 7, theme.accent());
			}
		}
		renderer.popClip();
		if (maxScroll > 0) {
			float barHeight = Math.max(12, height * height / contentHeight());
			float barY = y + (height - barHeight) * (offset / maxScroll);
			renderer.rounded(x + width - 3.5f, barY + 2, 2, barHeight - 4, 1, ColorUtil.withAlpha(theme.textSecondary(), 90));
		}
		renderer.pop();
		renderer.popAlpha();
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0) {
			return true;
		}
		int index = (int) ((mouseY - y - 2 + scroll.get()) / ROW);
		List<T> list = options.get();
		if (index >= 0 && index < list.size()) {
			onPick.accept(list.get(index));
			if (!multi) {
				close();
			}
		}
		return true;
	}

	@Override
	public boolean mouseScrolled(UiContext context, float mouseX, float mouseY, double amount) {
		scrollTarget -= (float) amount * ROW * 2;
		return true;
	}
}
