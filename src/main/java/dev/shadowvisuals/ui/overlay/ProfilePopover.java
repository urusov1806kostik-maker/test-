package dev.shadowvisuals.ui.overlay;

import java.util.function.Supplier;

import net.minecraft.client.Minecraft;
import net.minecraft.world.entity.player.PlayerSkin;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.core.ClientInfo;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.ui.clickgui.ProfileBadge;
import dev.shadowvisuals.ui.component.Component;
import dev.shadowvisuals.util.ColorUtil;
import dev.shadowvisuals.util.TimeFormat;

/** Profile panel: player, client version, session time, server, theme and profile. No sensitive data. */
public final class ProfilePopover extends Overlay {
	private static final float WIDTH = 170;
	private static final float ROW = 13;

	private final ShadowClient client;
	private final Component anchor;
	private final Supplier<PlayerSkin> skin;

	public ProfilePopover(ShadowClient client, Component anchor, Supplier<PlayerSkin> skin) {
		super(false);
		this.client = client;
		this.anchor = anchor;
		this.skin = skin;
	}

	@Override
	protected void layout(UiContext context) {
		float height = 44 + ROW * 5 + 8;
		float left = anchor.x();
		float top = Math.max(4, anchor.y() - height - 6);
		setBounds(left, top, WIDTH, height);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		HudContext.Privacy privacy = client.privacy();
		renderer.pushAlpha(presence());
		renderer.push();
		renderer.translate(0, (1 - presence()) * 5);
		renderer.surface(x, y, width, height, DesignTokens.RADIUS_L, ColorUtil.shade(theme.panel(), 0.02f), theme.border(), theme.shadow(), 16);
		renderer.gradientHorizontal(x, y, width, 3, DesignTokens.RADIUS_L, theme.accent(), theme.accentSecondary());
		float head = 26;
		if (privacy.hideName()) {
			renderer.rounded(x + 10, y + 10, head, head, 4, theme.accentMuted(90));
		} else {
			renderer.face(skin.get(), x + 10, y + 10, head);
		}
		renderer.text(ProfileBadge.displayName(privacy, context), x + 10 + head + 8, y + 12, context.text(DesignTokens.FONT_BODY), theme.textPrimary(),
			FontManager.Weight.SEMIBOLD, false);
		renderer.text(ClientInfo.NAME + " " + ClientInfo.version(), x + 10 + head + 8, y + 25, context.text(DesignTokens.FONT_CAPTION), theme.textSecondary());

		Minecraft minecraft = Minecraft.getInstance();
		String server = client.session().serverAddress(minecraft);
		String serverText = privacy.hideServer() ? context.tr("ui.profile.hidden")
			: server != null ? server : minecraft.getSingleplayerServer() != null ? context.tr("ui.profile.singleplayer") : context.tr("ui.profile.offline");
		float cursor = y + 46;
		row(context, renderer, theme, cursor, "ui.profile.session", client.session().inWorld() ? TimeFormat.duration(client.session().sessionMillis()) : "—");
		row(context, renderer, theme, cursor += ROW, "ui.profile.server", serverText);
		row(context, renderer, theme, cursor += ROW, "ui.profile.config", client.profiles().active());
		row(context, renderer, theme, cursor += ROW, "ui.profile.theme", context.i18n().enumName(client.theme().preset().get()));
		row(context, renderer, theme, cursor + ROW, "ui.profile.modules", Long.toString(client.modules().all().stream().filter(m -> m.isEnabled()).count()));
		renderer.pop();
		renderer.popAlpha();
	}

	private void row(UiContext context, Renderer2D renderer, ThemeManager theme, float rowY, String labelKey, String value) {
		float size = context.text(DesignTokens.FONT_SMALL);
		renderer.textMiddle(context.tr(labelKey), x + 10, rowY + ROW / 2f, size, theme.textSecondary());
		String shown = renderer.ellipsize(value, size, FontManager.Weight.MEDIUM, width * 0.55f);
		renderer.textMiddle(shown, x + width - 10, rowY + ROW / 2f, size, theme.textPrimary(), FontManager.Weight.MEDIUM, Renderer2D.Align.RIGHT);
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		return true;
	}
}
