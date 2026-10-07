package dev.shadowvisuals.modules.hud;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import net.minecraft.client.Minecraft;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;

import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.IntSetting;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.StringSetting;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Universal item counter: one class serves the totem, pearl and crystal counters and the user-defined
 * "Item Counters" list (comma-separated item ids). Counts are refreshed at most once per tick.
 */
public final class ItemCounterHud extends PanelHudModule {
	public enum Layout {
		HORIZONTAL,
		VERTICAL
	}

	private final StringSetting items;
	private final ModeSetting<Layout> layout = settings().add(new ModeSetting<>("layout", Layout.HORIZONTAL));
	private final BooleanSetting hideZero = settings().add(new BooleanSetting("hide_zero", false));
	private final IntSetting warnBelow = settings().add(new IntSetting("warn_below", 1, 0, 64));
	private final List<Item> parsed = new ArrayList<>();
	private final List<ItemStack> icons = new ArrayList<>();
	private int[] counts = new int[0];
	private int[] shown = new int[0];
	private String parsedFrom;
	private long lastCountTick = -1;

	public ItemCounterHud(String id, Category category, String defaultItems, HudAnchor anchor, float x, float y) {
		super(id, category, false, anchor, x, y);
		this.items = settings().add(new StringSetting("items", defaultItems, 256).validator(ItemCounterHud::isValidList));
	}

	static boolean isValidList(String value) {
		for (String part : value.split(",")) {
			String trimmed = part.trim().toLowerCase(Locale.ROOT);
			if (trimmed.isEmpty()) {
				continue;
			}
			Identifier id = Identifier.tryParse(trimmed);
			if (id == null) {
				return false;
			}
		}
		return true;
	}

	private void parseIfChanged() {
		if (items.get().equals(parsedFrom)) {
			return;
		}
		parsedFrom = items.get();
		parsed.clear();
		icons.clear();
		for (String part : parsedFrom.split(",")) {
			Identifier id = Identifier.tryParse(part.trim().toLowerCase(Locale.ROOT));
			if (id == null) {
				continue;
			}
			BuiltInRegistries.ITEM.get(id).ifPresent(holder -> {
				if (!parsed.contains(holder.value())) {
					parsed.add(holder.value());
					icons.add(new ItemStack(holder.value()));
				}
			});
		}
		counts = new int[parsed.size()];
		shown = new int[parsed.size()];
		lastCountTick = -1;
	}

	private void recount(Minecraft minecraft) {
		long tick = minecraft.level == null ? -1 : minecraft.level.getGameTime();
		if (tick == lastCountTick && tick != -1) {
			return;
		}
		lastCountTick = tick;
		java.util.Arrays.fill(counts, 0);
		if (minecraft.player == null) {
			return;
		}
		Inventory inventory = minecraft.player.getInventory();
		for (int slot = 0; slot < inventory.getContainerSize(); slot++) {
			ItemStack stack = inventory.getItem(slot);
			if (stack.isEmpty()) {
				continue;
			}
			for (int i = 0; i < parsed.size(); i++) {
				if (stack.is(parsed.get(i))) {
					counts[i] += stack.getCount();
				}
			}
		}
	}

	/** Total count of {@code item} in the local inventory (used by warnings). */
	public static int count(Minecraft minecraft, Item item) {
		if (minecraft.player == null) {
			return 0;
		}
		Inventory inventory = minecraft.player.getInventory();
		int total = 0;
		for (int slot = 0; slot < inventory.getContainerSize(); slot++) {
			ItemStack stack = inventory.getItem(slot);
			if (stack.is(item)) {
				total += stack.getCount();
			}
		}
		return total;
	}

	@Override
	protected boolean hasContent(HudContext context) {
		parseIfChanged();
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.player == null || parsed.isEmpty()) {
			return false;
		}
		if (!hideZero.get()) {
			return true;
		}
		recount(minecraft);
		for (int count : counts) {
			if (count > 0) {
				return true;
			}
		}
		return false;
	}

	@Override
	protected void renderContent(HudContext context) {
		parseIfChanged();
		Minecraft minecraft = Minecraft.getInstance();
		recount(minecraft);
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		boolean horizontal = layout.get() == Layout.HORIZONTAL;
		float icon = 14;
		float gap = 6;
		int shownCount = 0;
		float contentWidth = 0;
		for (int i = 0; i < parsed.size(); i++) {
			if (hideZero.get() && counts[i] == 0 && !context.editing()) {
				continue;
			}
			shown[shownCount++] = i;
			float entryWidth = icon + 3 + boldWidth(context, Integer.toString(counts[i]));
			contentWidth = horizontal ? contentWidth + entryWidth + (shownCount > 1 ? gap : 0) : Math.max(contentWidth, entryWidth);
		}
		float rowHeight = icon + 2;
		float width = Math.max(20, contentWidth) + PADDING * 2 + 2;
		float height = (horizontal ? rowHeight : Math.max(1, shownCount) * rowHeight) + PADDING * 2 - 2;
		panel(context, width, height);
		float x = PADDING + 2;
		float y = PADDING;
		for (int n = 0; n < shownCount; n++) {
			int index = shown[n];
			renderer.item(icons.get(index), x, y, icon);
			String value = Integer.toString(counts[index]);
			int color = counts[index] < warnBelow.getInt() ? theme.error() : counts[index] == warnBelow.getInt() ? theme.warning() : theme.textPrimary();
			bold(context, value, x + icon + 3, y + icon / 2f - renderer.fonts().visualCenter(TEXT), color);
			if (horizontal) {
				x += icon + 3 + boldWidth(context, value) + gap;
			} else {
				y += rowHeight;
			}
		}
		if (shownCount == 0) {
			text(context, context.tr("hud.label.no_items"), PADDING + 2, height / 2f - renderer.fonts().visualCenter(TEXT), ColorUtil.withAlpha(theme.textSecondary(), 200));
		}
		setSize(width, height);
	}
}
