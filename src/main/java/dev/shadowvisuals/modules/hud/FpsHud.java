package dev.shadowvisuals.modules.hud;

import net.minecraft.client.Minecraft;

import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.InfoHudModule;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.ui.Icon;

/** Frames per second, optionally colored by performance. */
public final class FpsHud extends InfoHudModule {
	private final BooleanSetting colored = settings().add(new BooleanSetting("colored", true));

	public FpsHud() {
		super("fps", Icon.BOLT, HudAnchor.TOP_LEFT, 4, 22);
	}

	@Override
	protected String value(HudContext context, Minecraft client) {
		return Integer.toString(client.getFps());
	}

	@Override
	protected int valueColor(HudContext context) {
		if (!colored.get()) {
			return context.theme().textPrimary();
		}
		int fps = Minecraft.getInstance().getFps();
		return fps >= 60 ? context.theme().success() : fps >= 30 ? context.theme().warning() : context.theme().error();
	}
}
