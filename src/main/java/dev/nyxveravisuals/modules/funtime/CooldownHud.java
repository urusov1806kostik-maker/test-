package dev.nyxveravisuals.modules.funtime;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import net.minecraft.client.Minecraft;
import net.minecraft.resources.Identifier;
import net.minecraft.world.item.ItemCooldowns;
import net.minecraft.world.item.ItemStack;

import dev.nyxveravisuals.hud.HudAnchor;
import dev.nyxveravisuals.hud.HudContext;
import dev.nyxveravisuals.hud.PanelHudModule;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.util.ColorUtil;
import dev.nyxveravisuals.util.TimeFormat;

/**
 * Item cooldowns exactly as the client knows them (vanilla cooldown packets: ender pearls, chorus fruit,
 * shields, wind charges...). Server-side custom timers are not guessed: if the client has no cooldown, none
 * is shown.
 */
public final class CooldownHud extends PanelHudModule {
	private record Entry(ItemStack icon, float remainingSeconds, float progress) {
	}

	private final List<Entry> entries = new ArrayList<>();
	private final List<Identifier> seenGroups = new ArrayList<>();

	public CooldownHud() {
		super("cooldowns", Category.FUNTIME, false, HudAnchor.BOTTOM_CENTER, 0, -76);
	}

	private void collect(Minecraft minecraft, float partialTick) {
		entries.clear();
		seenGroups.clear();
		var player = minecraft.player;
		if (player == null) {
			return;
		}
		ItemCooldowns cooldowns = player.getCooldowns();
		Map<Identifier, ItemCooldowns.CooldownInstance> active = cooldowns.cooldowns;
		if (active.isEmpty()) {
			return;
		}
		var inventory = player.getInventory();
		for (int slot = 0; slot < inventory.getContainerSize(); slot++) {
			ItemStack stack = inventory.getItem(slot);
			if (stack.isEmpty()) {
				continue;
			}
			Identifier group = cooldowns.getCooldownGroup(stack);
			ItemCooldowns.CooldownInstance instance = active.get(group);
			if (instance == null || seenGroups.contains(group)) {
				continue;
			}
			seenGroups.add(group);
			float remainingTicks = instance.endTime() - (cooldowns.tickCount + partialTick);
			if (remainingTicks <= 0) {
				continue;
			}
			float total = Math.max(1, instance.endTime() - instance.startTime());
			entries.add(new Entry(stack, remainingTicks / 20f, remainingTicks / total));
		}
	}

	@Override
	protected boolean hasContent(HudContext context) {
		var player = Minecraft.getInstance().player;
		return player != null && !player.getCooldowns().cooldowns.isEmpty();
	}

	@Override
	protected void renderContent(HudContext context) {
		collect(Minecraft.getInstance(), context.partialTick());
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float cell = 22;
		int count = Math.max(1, entries.size());
		float width = count * cell + (count - 1) * 4 + PADDING * 2;
		float height = cell + 9 + PADDING * 2 - 2;
		panel(context, width, height);
		float x = PADDING;
		for (Entry entry : entries) {
			renderer.rounded(x, PADDING - 1, cell, cell, 4, ColorUtil.withAlpha(theme.textPrimary(), 12));
			renderer.item(entry.icon(), x + 3, PADDING + 2, 16);
			renderer.rounded(x, PADDING - 1, cell, cell * entry.progress(), 4, ColorUtil.withAlpha(0xFF000000, 110));
			String time = TimeFormat.seconds(entry.remainingSeconds());
			renderer.text(time, x + cell / 2f, PADDING + cell + 1, 6.5f, theme.textPrimary(), Renderer2D.Align.CENTER);
			renderer.rounded(x + 2, PADDING + cell - 2.5f, (cell - 4) * (1 - entry.progress()), 1.5f, 0.75f, theme.accent());
			x += cell + 4;
		}
		if (entries.isEmpty()) {
			text(context, context.tr("hud.label.no_cooldowns"), PADDING, height / 2f - renderer.fonts().visualCenter(TEXT), theme.textSecondary());
			setSize(Math.max(width, width(context, context.tr("hud.label.no_cooldowns")) + PADDING * 2), height);
			return;
		}
		setSize(width, height);
	}
}
