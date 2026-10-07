package dev.shadowvisuals.modules.hud;

import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.PlayerInfo;

import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.InfoHudModule;
import dev.shadowvisuals.ui.Icon;

/** Latency reported by the server for the local player (the same value as the tab list). */
public final class PingHud extends InfoHudModule {
	public PingHud() {
		super("ping", Icon.GLOBE, HudAnchor.TOP_LEFT, 4, 40);
	}

	public static int latency(Minecraft client) {
		if (client.player == null || client.getConnection() == null) {
			return -1;
		}
		PlayerInfo info = client.getConnection().getPlayerInfo(client.player.getUUID());
		return info == null ? -1 : info.getLatency();
	}

	@Override
	protected String value(HudContext context, Minecraft client) {
		int latency = latency(client);
		return latency < 0 ? null : latency + " ms";
	}

	@Override
	protected int valueColor(HudContext context) {
		int latency = latency(Minecraft.getInstance());
		return latency < 80 ? context.theme().success() : latency < 160 ? context.theme().warning() : context.theme().error();
	}
}
