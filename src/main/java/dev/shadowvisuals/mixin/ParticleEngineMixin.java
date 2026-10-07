package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import net.minecraft.client.particle.Particle;
import net.minecraft.client.particle.ParticleEngine;
import net.minecraft.core.particles.ParticleOptions;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.visual.ParticleModifier;

/** Particle Modifier: filtered particles are simply never created on the client. */
@Mixin(ParticleEngine.class)
public abstract class ParticleEngineMixin {
	@Inject(method = "createParticle", at = @At("HEAD"), cancellable = true)
	private void shadowvisuals$filter(ParticleOptions options, double x, double y, double z, double vx, double vy, double vz,
		CallbackInfoReturnable<Particle> cir) {
		ParticleModifier modifier = Hooks.enabled(ParticleModifier.class);
		if (modifier != null && modifier.blocks(options)) {
			cir.setReturnValue(null);
		}
	}
}
