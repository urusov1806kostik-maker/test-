package dev.nyxveravisuals.core;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import net.minecraft.core.Holder;
import net.minecraft.core.particles.ColorParticleOption;
import net.minecraft.core.particles.ParticleOptions;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.entity.LivingEntity;

/**
 * Which status effects another entity has, as far as the client can know. Servers only send effect details for
 * your own player; for everyone else the client receives the colored effect particles of visible effects. Each
 * effect has its own particle color, so the colors identify the effects. Levels, durations and hidden
 * (particle-free) effects are unknown and are never guessed.
 */
public final class VisibleEffects {
	private static Map<Integer, Holder<MobEffect>> byColor;

	private VisibleEffects() {
	}

	/** Effects shown by {@code entity}'s particles, without duplicates, in particle order. */
	public static List<Holder<MobEffect>> of(LivingEntity entity) {
		List<ParticleOptions> particles = entity.getEntityData().get(LivingEntity.DATA_EFFECT_PARTICLES);
		if (particles.isEmpty()) {
			return List.of();
		}
		Map<Integer, Holder<MobEffect>> colors = colors();
		List<Holder<MobEffect>> effects = new ArrayList<>(particles.size());
		for (ParticleOptions particle : particles) {
			if (particle instanceof ColorParticleOption color && color.getType() == ParticleTypes.ENTITY_EFFECT) {
				int rgb = Math.round(color.getRed() * 255) << 16 | Math.round(color.getGreen() * 255) << 8 | Math.round(color.getBlue() * 255);
				Holder<MobEffect> effect = colors.get(rgb);
				if (effect != null && !effects.contains(effect)) {
					effects.add(effect);
				}
			}
		}
		return effects;
	}

	private static Map<Integer, Holder<MobEffect>> colors() {
		if (byColor == null) {
			Map<Integer, Holder<MobEffect>> map = new HashMap<>();
			BuiltInRegistries.MOB_EFFECT.listElements().forEach(effect -> map.putIfAbsent(effect.value().getColor() & 0xFFFFFF, effect));
			byColor = map;
		}
		return byColor;
	}
}
