package dev.shadowvisuals.modules.hud;

import java.util.Locale;

import net.minecraft.client.Minecraft;

import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.event.events.ClientTickEvent;
import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.InfoHudModule;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.ui.Icon;

/** Blocks per second, measured per tick and smoothed so the number does not flicker. */
public final class SpeedHud extends InfoHudModule {
	private final BooleanSetting horizontalOnly = settings().add(new BooleanSetting("horizontal_only", true));
	private final SmoothValue speed = new SmoothValue(0f, 6f);
	private double lastX = Double.NaN;
	private double lastY;
	private double lastZ;

	public SpeedHud() {
		super("bps", Icon.MOVE, HudAnchor.TOP_LEFT, 4, 58);
		on(ClientTickEvent.class, event -> {
			if (event.isPre()) {
				return;
			}
			var player = Minecraft.getInstance().player;
			if (player == null) {
				lastX = Double.NaN;
				speed.snap(0);
				return;
			}
			if (!Double.isNaN(lastX)) {
				double dx = player.getX() - lastX;
				double dy = horizontalOnly.get() ? 0 : player.getY() - lastY;
				double dz = player.getZ() - lastZ;
				double perTick = Math.sqrt(dx * dx + dy * dy + dz * dz);
				speed.setTarget(perTick > 50 ? 0f : (float) (perTick * 20));
			}
			lastX = player.getX();
			lastY = player.getY();
			lastZ = player.getZ();
		});
	}

	@Override
	protected void onDisable() {
		lastX = Double.NaN;
	}

	@Override
	protected String value(HudContext context, Minecraft client) {
		return client.player == null ? null : String.format(Locale.ROOT, "%.2f", speed.get());
	}
}
