package dev.nyxveravisuals.ui.overlay;

import java.util.ArrayList;
import java.util.List;

import dev.nyxveravisuals.core.UiSounds;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.util.ColorUtil;
import dev.nyxveravisuals.util.MathUtil;

/** The one context menu implementation; every right-click menu is built from {@link Item}s. */
public final class ContextMenu extends Overlay {
	private static final float ROW = 16;
	private static final float SEPARATOR = 5;

	public record Item(String labelKey, Icon icon, boolean danger, Runnable action) {
		public static final Item SEPARATOR_ITEM = new Item(null, null, false, null);
	}

	private final List<Item> items;
	private final float originX;
	private final float originY;

	private ContextMenu(List<Item> items, float originX, float originY) {
		super(false);
		this.items = items;
		this.originX = originX;
		this.originY = originY;
	}

	public static Builder at(float x, float y) {
		return new Builder(x, y);
	}

	public static final class Builder {
		private final float x;
		private final float y;
		private final List<Item> items = new ArrayList<>();

		private Builder(float x, float y) {
			this.x = x;
			this.y = y;
		}

		public Builder item(String labelKey, Icon icon, Runnable action) {
			items.add(new Item(labelKey, icon, false, action));
			return this;
		}

		public Builder danger(String labelKey, Icon icon, Runnable action) {
			items.add(new Item(labelKey, icon, true, action));
			return this;
		}

		public Builder separator() {
			items.add(Item.SEPARATOR_ITEM);
			return this;
		}

		public void open(UiContext context) {
			context.overlays().open(new ContextMenu(List.copyOf(items), x, y));
		}
	}

	private float contentHeight() {
		float height = 4;
		for (Item item : items) {
			height += item.labelKey() == null ? SEPARATOR : ROW;
		}
		return height;
	}

	@Override
	protected void layout(UiContext context) {
		float size = context.text(DesignTokens.FONT_SMALL);
		float menuWidth = DesignTokens.POPUP_MIN_WIDTH;
		for (Item item : items) {
			if (item.labelKey() != null) {
				menuWidth = Math.max(menuWidth, context.renderer().textWidth(context.tr(item.labelKey()), size) + 34);
			}
		}
		float menuHeight = contentHeight();
		float left = originX + menuWidth > context.width() - 4 ? originX - menuWidth : originX;
		float top = originY + menuHeight > context.height() - 4 ? originY - menuHeight : originY;
		setBounds(MathUtil.clamp(left, 4, context.width() - menuWidth - 4), MathUtil.clamp(top, 4, context.height() - menuHeight - 4), menuWidth, menuHeight);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		renderer.pushAlpha(presence());
		renderer.surface(x, y, width, height, DesignTokens.RADIUS_M, ColorUtil.shade(theme.panel(), 0.02f), theme.border(), theme.shadow(), 12);
		float size = context.text(DesignTokens.FONT_SMALL);
		float cursor = y + 2;
		for (Item item : items) {
			if (item.labelKey() == null) {
				renderer.rect(x + 6, cursor + SEPARATOR / 2f, width - 12, 1, theme.border());
				cursor += SEPARATOR;
				continue;
			}
			boolean rowHovered = contains(mouseX, mouseY) && mouseY >= cursor && mouseY < cursor + ROW;
			int base = item.danger() ? theme.error() : theme.textPrimary();
			if (rowHovered) {
				renderer.rounded(x + 2, cursor, width - 4, ROW, DesignTokens.RADIUS_S,
					item.danger() ? ColorUtil.withAlpha(theme.error(), 34) : ColorUtil.withAlpha(theme.textPrimary(), 16));
			}
			if (item.icon() != null) {
				item.icon().draw(renderer, x + DesignTokens.SPACE_S, cursor + (ROW - 8) / 2f, 8, item.danger() ? theme.error() : theme.textSecondary());
			}
			renderer.textMiddle(context.tr(item.labelKey()), x + DesignTokens.SPACE_S + 13, cursor + ROW / 2f, size, base);
			cursor += ROW;
		}
		renderer.popAlpha();
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		float cursor = y + 2;
		for (Item item : items) {
			float rowHeight = item.labelKey() == null ? SEPARATOR : ROW;
			if (item.action() != null && mouseY >= cursor && mouseY < cursor + rowHeight) {
				close();
				context.sounds().play(UiSounds.Kind.CLICK);
				item.action().run();
				return true;
			}
			cursor += rowHeight;
		}
		return true;
	}
}
