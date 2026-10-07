package dev.shadowvisuals.modules.hud;

import java.util.Locale;

import net.minecraft.client.Minecraft;
import net.minecraft.util.Mth;

import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.util.ColorUtil;

/** Heading strip with cardinal letters and degree ticks, interpolated with the frame for smooth motion. */
public final class CompassHud extends PanelHudModule {
	private static final float WIDTH = 150;
	private static final float HEIGHT = 20;
	private static final float DEGREES_VISIBLE = 120;

	private final BooleanSetting showDegrees = settings().add(new BooleanSetting("show_degrees", true));

	public CompassHud() {
		super("compass", Category.HUD, false, HudAnchor.TOP_CENTER, 0, 4);
	}

	@Override
	protected boolean hasContent(HudContext context) {
		return Minecraft.getInstance().player != null;
	}

	@Override
	protected void renderContent(HudContext context) {
		Minecraft minecraft = Minecraft.getInstance();
		Renderer2D renderer = context.renderer();
		panel(context, WIDTH, HEIGHT);
		float yaw = minecraft.player == null ? 0 : Mth.wrapDegrees(minecraft.player.getViewYRot(context.partialTick()));
		float heading = (yaw + 180f) % 360f;
		float pixelsPerDegree = (WIDTH - 12) / DEGREES_VISIBLE;
		float center = WIDTH / 2f;
		renderer.pushClip(3, 0, WIDTH - 6, HEIGHT);
		for (int degree = 0; degree < 360; degree += 15) {
			float delta = Mth.wrapDegrees(degree - heading);
			if (Math.abs(delta) > DEGREES_VISIBLE / 2f + 10) {
				continue;
			}
			float x = center + delta * pixelsPerDegree;
			float fade = 1f - Math.min(1f, Math.abs(delta) / (DEGREES_VISIBLE / 2f));
			int alpha = Math.round(255 * (0.25f + 0.75f * fade));
			String letter = switch (degree) {
				case 0 -> "N";
				case 90 -> "E";
				case 180 -> "S";
				case 270 -> "W";
				default -> null;
			};
			if (letter != null) {
				int color = degree == 0 ? context.theme().error() : context.theme().textPrimary();
				renderer.text(letter, x, HEIGHT / 2f - renderer.fonts().visualCenter(TEXT), TEXT, ColorUtil.withAlpha(color, alpha),
					FontManager.Weight.SEMIBOLD, Renderer2D.Align.CENTER);
			} else {
				float tick = degree % 45 == 0 ? 5 : 3;
				renderer.rect(x - 0.5f, HEIGHT / 2f - tick / 2f, 1, tick, ColorUtil.withAlpha(context.theme().textSecondary(), alpha));
			}
		}
		renderer.popClip();
		renderer.rounded(center - 0.75f, 2, 1.5f, 3.5f, 0.75f, context.theme().accent());
		if (showDegrees.get()) {
			String text = String.format(Locale.ROOT, "%.0f°", heading);
			renderer.text(text, center, HEIGHT + 2, 6.5f, context.theme().textSecondary(), Renderer2D.Align.CENTER);
			setSize(WIDTH, HEIGHT + 10);
		} else {
			setSize(WIDTH, HEIGHT);
		}
	}
}
