package dev.nyxveravisuals.ui.clickgui;

import java.util.function.Supplier;

import net.minecraft.client.Minecraft;
import net.minecraft.world.entity.player.PlayerSkin;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.core.UiSounds;
import dev.nyxveravisuals.hud.HudContext;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.overlay.ProfilePopover;
import dev.nyxveravisuals.util.ColorUtil;

/** Avatar, name and active config profile; opens the profile panel. Respects recording mode. */
public final class ProfileBadge extends Component {
	private final NyxveraClient client;
	private final Supplier<PlayerSkin> skin;

	public ProfileBadge(NyxveraClient client) {
		this.client = client;
		Minecraft minecraft = Minecraft.getInstance();
		this.skin = minecraft.getSkinManager().createLookup(minecraft.getGameProfile(), false);
	}

	public static String displayName(HudContext.Privacy privacy, UiContext context) {
		return privacy.hideName() ? context.tr("ui.profile.hidden_name") : Minecraft.getInstance().getUser().getName();
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_M, ColorUtil.shade(theme.card(), hover() * 0.04f));
		renderer.outline(x, y, width, height, DesignTokens.RADIUS_M, 1, theme.border());
		float head = height - 10;
		HudContext.Privacy privacy = client.privacy();
		if (privacy.hideName()) {
			renderer.rounded(x + 5, y + 5, head, head, 3, theme.accentMuted(90));
		} else {
			renderer.face(skin.get(), x + 5, y + 5, head);
		}
		float textX = x + 5 + head + 6;
		float maxWidth = width - (textX - x) - 5;
		renderer.text(renderer.ellipsize(displayName(privacy, context), context.text(DesignTokens.FONT_SMALL), FontManager.Weight.SEMIBOLD, maxWidth),
			textX, y + 5, context.text(DesignTokens.FONT_SMALL), theme.textPrimary(), FontManager.Weight.SEMIBOLD, false);
		renderer.text(renderer.ellipsize(client.profiles().active(), context.text(DesignTokens.FONT_CAPTION), FontManager.Weight.MEDIUM, maxWidth),
			textX, y + height - 5 - context.text(DesignTokens.FONT_CAPTION) * 1.2f, context.text(DesignTokens.FONT_CAPTION), theme.textSecondary());
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0 || !contains(mouseX, mouseY)) {
			return false;
		}
		context.sounds().play(UiSounds.Kind.CLICK);
		context.overlays().open(new ProfilePopover(client, this, skin));
		return true;
	}
}
