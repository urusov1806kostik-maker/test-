package dev.shadowvisuals.ui.clickgui;

import java.util.EnumMap;
import java.util.Map;
import java.util.function.Consumer;

import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.core.ClientInfo;
import dev.shadowvisuals.core.UiSounds;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.ui.component.Component;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Left navigation. The active page is marked by a pill that glides between rows (frame-rate independent),
 * rows fade on hover, and the profile badge sits at the bottom.
 */
public final class Sidebar extends Component {
	private static final float ROW = 19;
	private static final float HEADER = 38;
	private static final float SECTION_GAP = 9;

	private final Consumer<Page> onSelect;
	private final ProfileBadge badge;
	private final SmoothValue indicatorY = new SmoothValue(-1f, 18f);
	private final Map<Page, Animation> rowHover = new EnumMap<>(Page.class);
	private Page selected;

	public Sidebar(Page selected, Consumer<Page> onSelect, ProfileBadge badge) {
		this.selected = selected;
		this.onSelect = onSelect;
		this.badge = badge;
		for (Page page : Page.values()) {
			rowHover.put(page, new Animation(0f, DesignTokens.DURATION_HOVER, Easing.EASE_OUT_QUAD));
		}
	}

	public void select(Page page) {
		this.selected = page;
	}

	private float rowY(Page page) {
		float cursor = y + HEADER;
		for (Page candidate : Page.values()) {
			if (candidate.startsSection()) {
				cursor += SECTION_GAP;
			}
			if (candidate == page) {
				return cursor;
			}
			cursor += ROW;
		}
		return cursor;
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();

		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_XL, ColorUtil.shade(theme.panel(), -0.12f));
		renderer.rect(x + width - 1, y + 8, 1, height - 16, theme.border());

		float dotSize = 9;
		float headerY = y + 15;
		renderer.gradientHorizontal(x + 12, headerY - dotSize / 2f, dotSize, dotSize, 3, theme.accent(), theme.accentSecondary());
		renderer.textMiddle("Shadow", x + 12 + dotSize + 6, headerY - 1, context.text(DesignTokens.FONT_BODY), theme.textPrimary(),
			FontManager.Weight.SEMIBOLD, Renderer2D.Align.LEFT);
		float nameWidth = renderer.textWidth("Shadow ", context.text(DesignTokens.FONT_BODY), FontManager.Weight.SEMIBOLD);
		renderer.textMiddle("Visuals", x + 12 + dotSize + 6 + nameWidth, headerY - 1, context.text(DesignTokens.FONT_BODY), theme.textSecondary(),
			FontManager.Weight.MEDIUM, Renderer2D.Align.LEFT);
		renderer.textMiddle("v" + ClientInfo.version(), x + 12 + dotSize + 6, headerY + 9, context.text(DesignTokens.FONT_CAPTION) * 0.9f,
			theme.textDisabled());

		float target = rowY(selected);
		if (indicatorY.target() < 0) {
			indicatorY.snap(target);
		}
		indicatorY.setTarget(target);
		float pillY = indicatorY.get();
		renderer.rounded(x + 6, pillY, width - 12, ROW - 2, DesignTokens.RADIUS_M, theme.accentMuted(34));
		renderer.gradientVertical(x + 6, pillY + 4, 2, ROW - 10, 1, theme.accent(), theme.accentSecondary());

		float size = context.text(DesignTokens.FONT_SMALL);
		for (Page page : Page.values()) {
			float rowY = rowY(page);
			if (page.startsSection()) {
				renderer.rect(x + 12, rowY - SECTION_GAP / 2f - 0.5f, width - 24, 1, theme.border());
			}
			boolean rowHovered = mouseX >= x + 6 && mouseX < x + width - 6 && mouseY >= rowY && mouseY < rowY + ROW - 2;
			Animation hoverAnimation = rowHover.get(page);
			hoverAnimation.animateTo(rowHovered && page != selected ? 1f : 0f);
			float hover = hoverAnimation.value();
			if (hover > 0.01f) {
				renderer.rounded(x + 6, rowY, width - 12, ROW - 2, DesignTokens.RADIUS_M, ColorUtil.withAlpha(theme.textPrimary(), Math.round(hover * 12)));
			}
			boolean active = page == selected;
			int color = active ? theme.textPrimary() : ColorUtil.lerp(theme.textSecondary(), theme.textPrimary(), hover * 0.7f);
			float iconSize = DesignTokens.ICON_SMALL + 1;
			float iconX = x + 14 + hover * 1.5f;
			page.icon().draw(renderer, iconX, rowY + (ROW - 2 - iconSize) / 2f, iconSize, active ? theme.accent() : color);
			String label = renderer.ellipsize(context.tr(page.translationKey()), size, FontManager.Weight.MEDIUM, width - 44);
			renderer.textMiddle(label, iconX + iconSize + 7, rowY + (ROW - 2) / 2f, size, color,
				active ? FontManager.Weight.SEMIBOLD : FontManager.Weight.MEDIUM, Renderer2D.Align.LEFT);
		}

		float badgeHeight = 30;
		badge.setBounds(x + 6, y + height - badgeHeight - 6, width - 12, badgeHeight);
		badge.render(context, mouseX, mouseY);
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (!contains(mouseX, mouseY)) {
			return false;
		}
		if (badge.mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		if (button != 0) {
			return true;
		}
		for (Page page : Page.values()) {
			float rowY = rowY(page);
			if (mouseY >= rowY && mouseY < rowY + ROW - 2 && mouseX >= x + 6 && mouseX < x + width - 6) {
				if (page != selected) {
					selected = page;
					context.sounds().play(UiSounds.Kind.CLICK);
					onSelect.accept(page);
				}
				return true;
			}
		}
		return true;
	}
}
