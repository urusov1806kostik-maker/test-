package dev.nyxveravisuals.modules.iface;

import net.minecraft.client.AttackIndicatorStatus;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.animation.SmoothValue;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.NumberSetting;

/**
 * Configurable crosshair. Every edge is snapped to the screen pixel grid, so it stays sharp at any GUI
 * scale; the dynamic mode opens the gap while moving or while the attack is recharging.
 */
public final class CustomCrosshair extends Module {
	public enum Style {
		CROSS,
		CROSS_DOT,
		DOT,
		CIRCLE
	}

	private final NyxveraClient client;
	private final ModeSetting<Style> style = settings().add(new ModeSetting<>("style", Style.CROSS));
	private final NumberSetting size = settings().add(new NumberSetting("length", 4, 1, 12, 0.5));
	private final NumberSetting gap = settings().add(new NumberSetting("gap", 2, 0, 8, 0.5));
	private final NumberSetting thickness = settings().add(new NumberSetting("thickness", 1, 0.5, 4, 0.5));
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFFFFFFFF, true));
	private final BooleanSetting outline = settings().add(new BooleanSetting("outline", true));
	private final ColorSetting outlineColor = settings().add(new ColorSetting("outline_color", 0xAA000000, true)).dependsOn(outline);
	private final BooleanSetting dynamic = settings().add(new BooleanSetting("dynamic", true));
	private final BooleanSetting attackIndicator = settings().add(new BooleanSetting("attack_indicator", true));
	private final BooleanSetting thirdPerson = settings().add(new BooleanSetting("show_third_person", false));
	private final SmoothValue spread = new SmoothValue(0f, 14f);

	public CustomCrosshair(NyxveraClient client) {
		super("custom_crosshair", Category.INTERFACE);
		this.client = client;
	}

	public void render(GuiGraphics graphics, DeltaTracker deltaTracker) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.player == null || minecraft.options.hideGui) {
			return;
		}
		if (!minecraft.options.getCameraType().isFirstPerson() && !thirdPerson.get()) {
			return;
		}
		Renderer2D renderer = client.renderer().begin(graphics);
		float scale = minecraft.getWindow().getGuiScale();
		float centerX = snap(graphics.guiWidth() / 2f, scale);
		float centerY = snap(graphics.guiHeight() / 2f, scale);
		float partialTick = deltaTracker.getGameTimeDeltaPartialTick(false);
		float cooldown = minecraft.player.getAttackStrengthScale(partialTick);
		if (dynamic.get()) {
			double speed = minecraft.player.getDeltaMovement().horizontalDistance();
			spread.setTarget((float) Math.min(4, speed * 18) + (1 - cooldown) * 3);
		} else {
			spread.setTarget(0);
		}
		float currentGap = snap(gap.getFloat() + spread.get(), scale);
		float length = snap(size.getFloat(), scale);
		float width = Math.max(1f / scale, snap(thickness.getFloat(), scale));
		int main = color.color();
		int border = outlineColor.color();
		float o = outline.get() ? 1f / scale : 0;
		Style current = style.get();
		if (current == Style.CROSS || current == Style.CROSS_DOT) {
			bar(renderer, centerX - width / 2f, centerY - currentGap - length, width, length, main, border, o);
			bar(renderer, centerX - width / 2f, centerY + currentGap, width, length, main, border, o);
			bar(renderer, centerX - currentGap - length, centerY - width / 2f, length, width, main, border, o);
			bar(renderer, centerX + currentGap, centerY - width / 2f, length, width, main, border, o);
		}
		if (current == Style.CROSS_DOT || current == Style.DOT) {
			float dot = Math.max(width, 2f / scale) + (current == Style.DOT ? 1f / scale : 0);
			bar(renderer, centerX - dot / 2f, centerY - dot / 2f, dot, dot, main, border, o);
		}
		if (current == Style.CIRCLE) {
			float radius = currentGap + length / 2f;
			if (o > 0) {
				renderer.ring(centerX, centerY, radius + o, width + o * 2, border);
			}
			renderer.ring(centerX, centerY, radius, width, main);
			renderer.circle(centerX, centerY, Math.max(width, 1f / scale), main);
		}
		if (attackIndicator.get() && minecraft.options.attackIndicator().get() == AttackIndicatorStatus.CROSSHAIR && cooldown < 1f) {
			float barWidth = snap(12, scale);
			float y = centerY + currentGap + length + snap(3, scale);
			renderer.rounded(centerX - barWidth / 2f, y, barWidth, 2f / scale * 2, 1f / scale, 0x66000000);
			renderer.rounded(centerX - barWidth / 2f, y, barWidth * cooldown, 2f / scale * 2, 1f / scale, main);
		}
	}

	private static void bar(Renderer2D renderer, float x, float y, float width, float height, int color, int border, float outline) {
		if (outline > 0) {
			renderer.rect(x - outline, y - outline, width + outline * 2, height + outline * 2, border);
		}
		renderer.rect(x, y, width, height, color);
	}

	private static float snap(float value, float scale) {
		return Math.round(value * scale) / scale;
	}
}
