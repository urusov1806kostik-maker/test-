package dev.shadowvisuals.modules.iface;

import java.util.Map;
import java.util.UUID;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.components.LerpingBossEvent;
import net.minecraft.world.BossEvent;

import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.setting.IntSetting;

/** Restyled boss bars with the server's names and progress; movable in the HUD editor. */
public final class CustomBossBar extends PanelHudModule {
	private static final float WIDTH = 182;

	private final IntSetting maxBars = settings().add(new IntSetting("max_bars", 4, 1, 8));

	public CustomBossBar() {
		super("custom_boss_bar", Category.INTERFACE, false, HudAnchor.TOP_CENTER, 0, 36);
	}

	private static Map<UUID, LerpingBossEvent> events() {
		return Minecraft.getInstance().gui.getBossOverlay().events;
	}

	@Override
	protected boolean hasContent(HudContext context) {
		return !events().isEmpty();
	}

	@Override
	protected void renderContent(HudContext context) {
		Renderer2D renderer = context.renderer();
		float rowHeight = 20;
		int count = 0;
		float y = 0;
		for (LerpingBossEvent event : events().values()) {
			if (count++ >= maxBars.getInt()) {
				break;
			}
			int color = color(event.getColor());
			renderer.component(event.getName(), WIDTH / 2f - Minecraft.getInstance().font.width(event.getName()) / 2f, y + 2, 1f, 0xFFFFFFFF, true);
			float barY = y + 12;
			renderer.rounded(0, barY, WIDTH, 5, 2.5f, 0x88000000);
			renderer.gradientHorizontal(0, barY, WIDTH * Math.max(0, Math.min(1, event.getProgress())), 5, 2.5f,
				dev.shadowvisuals.util.ColorUtil.shade(color, -0.15f), color);
			y += rowHeight;
		}
		if (count == 0 && context.editing()) {
			renderer.rounded(0, 12, WIDTH, 5, 2.5f, context.theme().accentMuted(120));
			y = rowHeight;
		}
		setSize(WIDTH, Math.max(rowHeight, y));
	}

	private static int color(BossEvent.BossBarColor color) {
		return switch (color) {
			case PINK -> 0xFFF27BC9;
			case BLUE -> 0xFF5B8CFF;
			case RED -> 0xFFF2555A;
			case GREEN -> 0xFF3DD68C;
			case YELLOW -> 0xFFF5D244;
			case PURPLE -> 0xFF9B6CF2;
			default -> 0xFFE9EAF0;
		};
	}
}
