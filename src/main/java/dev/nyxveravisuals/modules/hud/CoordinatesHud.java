package dev.nyxveravisuals.modules.hud;

import net.minecraft.client.Minecraft;
import net.minecraft.world.level.Level;

import dev.nyxveravisuals.hud.HudAnchor;
import dev.nyxveravisuals.hud.HudContext;
import dev.nyxveravisuals.hud.InfoHudModule;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.util.Numbers;

/** Player position with optional Nether/Overworld conversion. Hidden by recording mode. */
public final class CoordinatesHud extends InfoHudModule {
	private final BooleanSetting decimals = settings().add(new BooleanSetting("decimals", false));
	private final BooleanSetting netherConversion = settings().add(new BooleanSetting("nether_conversion", true));

	public CoordinatesHud() {
		super("coordinates", Icon.PIN, HudAnchor.BOTTOM_LEFT, 4, -24);
	}

	@Override
	protected String value(HudContext context, Minecraft client) {
		if (client.player == null || client.level == null) {
			return null;
		}
		if (context.privacy().hideCoordinates()) {
			return context.tr("ui.profile.hidden");
		}
		double x = client.player.getX();
		double y = client.player.getY();
		double z = client.player.getZ();
		String main = format(x, y, z);
		if (!netherConversion.get()) {
			return main;
		}
		if (client.level.dimension() == Level.NETHER) {
			return main + "  (" + format(x * 8, y, z * 8) + ")";
		}
		if (client.level.dimension() == Level.OVERWORLD) {
			return main + "  (" + format(x / 8, y, z / 8) + ")";
		}
		return main;
	}

	private String format(double x, double y, double z) {
		return decimals.get()
			? Numbers.appendFixed(Numbers.appendFixed(Numbers.appendFixed(new StringBuilder(24), x, 1).append(", "), y, 1).append(", "), z, 1).toString()
			: (int) Math.floor(x) + ", " + (int) Math.floor(y) + ", " + (int) Math.floor(z);
	}
}
