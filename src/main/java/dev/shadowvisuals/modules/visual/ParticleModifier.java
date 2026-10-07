package dev.shadowvisuals.modules.visual;

import net.minecraft.core.particles.ParticleOptions;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.particles.ParticleType;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.NumberSetting;

/** Client-side particle filter: hide noisy particle groups and thin out the rest. */
public final class ParticleModifier extends Module {
	private final BooleanSetting explosions = settings().add(new BooleanSetting("hide_explosions", true));
	private final BooleanSetting blockBreak = settings().add(new BooleanSetting("hide_block_breaking", false));
	private final BooleanSetting potions = settings().add(new BooleanSetting("hide_potion_swirls", false));
	private final BooleanSetting weather = settings().add(new BooleanSetting("hide_weather", false));
	private final BooleanSetting totem = settings().add(new BooleanSetting("hide_totem", false));
	private final NumberSetting density = settings().add(new NumberSetting("density", 1.0, 0.0, 1.0, 0.05).suffix("x"));
	private int counter;

	public ParticleModifier() {
		super("particle_modifier", Category.VISUAL);
	}

	/** True if the particle should not be spawned. */
	public boolean blocks(ParticleOptions options) {
		ParticleType<?> type = options.getType();
		if (explosions.get() && (type == ParticleTypes.EXPLOSION || type == ParticleTypes.EXPLOSION_EMITTER || type == ParticleTypes.POOF)) {
			return true;
		}
		if (blockBreak.get() && (type == ParticleTypes.BLOCK || type == ParticleTypes.BLOCK_MARKER)) {
			return true;
		}
		if (potions.get() && (type == ParticleTypes.ENTITY_EFFECT || type == ParticleTypes.EFFECT || type == ParticleTypes.INSTANT_EFFECT)) {
			return true;
		}
		if (weather.get() && (type == ParticleTypes.RAIN || type == ParticleTypes.DRIPPING_WATER || type == ParticleTypes.SPLASH)) {
			return true;
		}
		if (totem.get() && type == ParticleTypes.TOTEM_OF_UNDYING) {
			return true;
		}
		float keep = density.getFloat();
		if (keep >= 1f) {
			return false;
		}
		counter++;
		return (counter % 100) >= Math.round(keep * 100);
	}
}
