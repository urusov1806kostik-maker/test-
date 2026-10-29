package dev.nyxveravisuals.modules.visual;

import net.minecraft.client.Minecraft;
import net.minecraft.world.effect.MobEffects;

import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.NumberSetting;

/** Lowers the first-person fire overlay, or hides it while you are fire resistant. */
public final class FireOverlay extends Module {
	private final NumberSetting height = settings().add(new NumberSetting("lower_by", 0.3, 0.0, 0.6, 0.02));
	private final BooleanSetting hideResistant = settings().add(new BooleanSetting("hide_with_resistance", true));

	public FireOverlay() {
		super("fire_overlay", Category.VISUAL);
	}

	public boolean hide() {
		var player = Minecraft.getInstance().player;
		return hideResistant.get() && player != null && player.hasEffect(MobEffects.FIRE_RESISTANCE);
	}

	public float offset() {
		return height.getFloat();
	}
}
