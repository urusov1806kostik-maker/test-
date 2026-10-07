package dev.shadowvisuals.hud;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.animation.AnimationClock;
import dev.shadowvisuals.core.ClientSettings;
import dev.shadowvisuals.notification.NotificationManager;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.util.ColorUtil;

/** Draws notification toasts in the configured corner: slide + fade in, stacked, with a lifetime bar. */
public final class NotificationRenderer {
	private static final float WIDTH = 150;
	private static final float HEIGHT = 30;
	private static final float GAP = 5;
	private static final float MARGIN = 8;

	private final ShadowClient client;

	public NotificationRenderer(ShadowClient client) {
		this.client = client;
	}

	/** Above any open screen (called after the screen renders). */
	public void renderOverScreen(GuiGraphics graphics, Screen screen) {
		Renderer2D renderer = client.renderer().begin(graphics);
		render(renderer, graphics.guiWidth(), graphics.guiHeight());
	}

	public void render(Renderer2D renderer, float screenWidth, float screenHeight) {
		NotificationManager manager = client.notifications();
		manager.update();
		if (manager.active().isEmpty()) {
			return;
		}
		ThemeManager theme = client.theme();
		ClientSettings.NotificationCorner corner = client.settings().notificationCorner.get();
		boolean right = corner == ClientSettings.NotificationCorner.TOP_RIGHT || corner == ClientSettings.NotificationCorner.BOTTOM_RIGHT;
		boolean bottom = corner == ClientSettings.NotificationCorner.BOTTOM_RIGHT || corner == ClientSettings.NotificationCorner.BOTTOM_LEFT;
		double now = AnimationClock.global().now();
		for (NotificationManager.Notification notification : manager.active()) {
			float visibility = notification.visibility();
			if (visibility <= 0.001f) {
				continue;
			}
			float slot = notification.slot();
			float x = right ? screenWidth - WIDTH - MARGIN : MARGIN;
			float slide = (1 - visibility) * (WIDTH * 0.35f) * (right ? 1 : -1);
			float y = bottom ? screenHeight - MARGIN - HEIGHT - slot * (HEIGHT + GAP) : MARGIN + slot * (HEIGHT + GAP);
			if (bottom && y < 0 || !bottom && y > screenHeight) {
				continue;
			}
			drawCard(renderer, theme, notification, x + slide, y, visibility, notification.remaining(now));
		}
	}

	private void drawCard(Renderer2D renderer, ThemeManager theme, NotificationManager.Notification notification,
		float x, float y, float alpha, float remaining) {
		int accent = switch (notification.type()) {
			case SUCCESS -> theme.success();
			case WARNING -> theme.warning();
			case ERROR -> theme.error();
			default -> theme.accent();
		};
		Icon icon = switch (notification.type()) {
			case SUCCESS -> Icon.SUCCESS;
			case WARNING -> Icon.WARNING;
			case ERROR -> Icon.ERROR;
			default -> Icon.INFO;
		};
		renderer.pushAlpha(alpha);
		renderer.surface(x, y, WIDTH, HEIGHT, DesignTokens.RADIUS_L, ColorUtil.withAlpha(theme.panel(), 240), theme.border(), theme.shadow(), 12);
		renderer.circle(x + 15, y + HEIGHT / 2f, 9, ColorUtil.withAlpha(accent, 36));
		icon.draw(renderer, x + 9.5f, y + HEIGHT / 2f - 5.5f, 11, accent);
		float textX = x + 30;
		float maxWidth = WIDTH - 38;
		float titleSize = DesignTokens.FONT_SMALL;
		renderer.text(renderer.ellipsize(notification.title(), titleSize, FontManager.Weight.SEMIBOLD, maxWidth), textX, y + 6, titleSize,
			theme.textPrimary(), FontManager.Weight.SEMIBOLD, false);
		renderer.text(renderer.ellipsize(notification.message(), DesignTokens.FONT_CAPTION, FontManager.Weight.MEDIUM, maxWidth), textX, y + 16.5f,
			DesignTokens.FONT_CAPTION, theme.textSecondary());
		float barWidth = (WIDTH - 16) * remaining;
		if (barWidth > 0.5f) {
			renderer.rounded(x + 8, y + HEIGHT - 3, barWidth, 1.5f, 0.75f, ColorUtil.withAlpha(accent, 150));
		}
		renderer.popAlpha();
	}
}
