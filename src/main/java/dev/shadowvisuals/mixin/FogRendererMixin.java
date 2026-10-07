package dev.shadowvisuals.mixin;

import java.nio.ByteBuffer;

import org.joml.Vector4f;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import com.llamalad7.mixinextras.sugar.Local;

import net.minecraft.client.Camera;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.client.renderer.fog.FogRenderer;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.level.material.FogType;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.world.FogControl;
import dev.shadowvisuals.util.ColorUtil;

/** Fog Control: scales atmospheric fog only (no fluids, blindness or darkness). */
@Mixin(FogRenderer.class)
public abstract class FogRendererMixin {
	@WrapOperation(method = "setupFog", at = @At(value = "INVOKE",
		target = "Lnet/minecraft/client/renderer/fog/FogRenderer;updateBuffer(Ljava/nio/ByteBuffer;ILorg/joml/Vector4f;FFFFFF)V"))
	private void shadowvisuals$fog(FogRenderer renderer, ByteBuffer buffer, int offset, Vector4f color, float environmentalStart,
		float environmentalEnd, float renderDistanceStart, float renderDistanceEnd, float skyEnd, float cloudEnd, Operation<Void> original,
		@Local(argsOnly = true) Camera camera, @Local(argsOnly = true) ClientLevel level) {
		FogControl fog = Hooks.enabled(FogControl.class);
		boolean atmospheric = camera.getFluidInCamera() == FogType.NONE
			&& !(camera.entity() instanceof LivingEntity living && (living.hasEffect(MobEffects.BLINDNESS) || living.hasEffect(MobEffects.DARKNESS)));
		if (fog == null || !atmospheric || level == null) {
			original.call(renderer, buffer, offset, color, environmentalStart, environmentalEnd, renderDistanceStart, renderDistanceEnd, skyEnd, cloudEnd);
			return;
		}
		float factor = fog.multiplier(level.dimension().identifier().toString());
		Vector4f fogColor = color;
		if (fog.customColor()) {
			int argb = fog.color();
			fogColor = new Vector4f(ColorUtil.red(argb) / 255f, ColorUtil.green(argb) / 255f, ColorUtil.blue(argb) / 255f, color.w);
			color.set(fogColor);
		}
		original.call(renderer, buffer, offset, fogColor, environmentalStart * factor, environmentalEnd * factor,
			renderDistanceStart * factor, renderDistanceEnd * factor, skyEnd * factor, cloudEnd * factor);
	}
}
