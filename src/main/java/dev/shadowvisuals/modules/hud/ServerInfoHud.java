package dev.shadowvisuals.modules.hud;

import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.ClientPacketListener;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.ui.Icon;

/** Server address, brand, online players and your ping. The address respects recording mode. */
public final class ServerInfoHud extends PanelHudModule {
	private final ShadowClient client;

	public ServerInfoHud(ShadowClient client) {
		super("server_info", Category.HUD, false, HudAnchor.TOP_LEFT, 4, 120);
		this.client = client;
	}

	@Override
	protected boolean isPrivate() {
		return true;
	}

	@Override
	protected boolean hasContent(HudContext context) {
		return Minecraft.getInstance().getConnection() != null;
	}

	@Override
	protected void renderContent(HudContext context) {
		Minecraft minecraft = Minecraft.getInstance();
		Renderer2D renderer = context.renderer();
		ClientPacketListener connection = minecraft.getConnection();
		String address = client.session().serverAddress(minecraft);
		String server = address == null ? context.tr("ui.profile.singleplayer") : context.privacy().hideServer() ? context.tr("ui.profile.hidden") : address;
		String brand = connection == null || connection.serverBrand() == null ? "—" : connection.serverBrand();
		String online = connection == null ? "—" : Integer.toString(connection.getOnlinePlayers().size());
		int latency = PingHud.latency(minecraft);
		String[] labels = {context.tr("ui.profile.server"), context.tr("hud.label.brand"), context.tr("hud.label.online"), context.tr("hud.label.ping")};
		String[] values = {server, brand, online, latency < 0 ? "—" : latency + " ms"};
		float rowHeight = renderer.lineHeight(TEXT) + 2;
		float labelWidth = 0;
		float valueWidth = 0;
		for (int i = 0; i < labels.length; i++) {
			labelWidth = Math.max(labelWidth, width(context, labels[i]));
			valueWidth = Math.max(valueWidth, Math.min(110, boldWidth(context, values[i])));
		}
		float header = rowHeight + 2;
		float width = Math.max(boldWidth(context, context.tr("hud.label.server_info")) + 16, labelWidth + valueWidth + 12) + PADDING * 2 + 2;
		float height = header + labels.length * rowHeight + PADDING * 2 - 2;
		panel(context, width, height);
		Icon.GLOBE.draw(renderer, PADDING + 2, PADDING, 9, context.theme().accent());
		bold(context, context.tr("hud.label.server_info"), PADDING + 14, PADDING + 4.5f - renderer.fonts().visualCenter(TEXT), context.theme().textPrimary());
		float y = PADDING + header;
		for (int i = 0; i < labels.length; i++) {
			float textY = y + rowHeight / 2f - renderer.fonts().visualCenter(TEXT);
			text(context, labels[i], PADDING + 2, textY, context.theme().textSecondary());
			String value = renderer.ellipsize(values[i], TEXT, dev.shadowvisuals.render.font.FontManager.Weight.SEMIBOLD, 110);
			bold(context, value, width - PADDING - boldWidth(context, value), textY, context.theme().textPrimary());
			y += rowHeight;
		}
		setSize(width, height);
	}
}
