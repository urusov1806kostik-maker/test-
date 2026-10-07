package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.ModifyArg;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import com.llamalad7.mixinextras.injector.ModifyExpressionValue;

import net.minecraft.client.Camera;

import net.minecraft.client.DeltaTracker;
import net.minecraft.client.renderer.GameRenderer;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.camera.FovControl;
import dev.shadowvisuals.modules.camera.HurtCamera;
import dev.shadowvisuals.modules.camera.ViewBobbing;
import dev.shadowvisuals.modules.camera.Zoom;

/** Frame clock, hurt camera, view bobbing and FOV hooks. */
@Mixin(GameRenderer.class)
public abstract class GameRendererMixin {
	@Inject(method = "render", at = @At("HEAD"))
	private void shadowvisuals$onFrameStart(DeltaTracker deltaTracker, boolean renderLevel, CallbackInfo ci) {
		ShadowClient client = ShadowClient.get();
		if (client != null) {
			client.onFrameStart();
		}
	}

	@ModifyArg(method = "bobHurt", at = @At(value = "INVOKE", target = "Lcom/mojang/math/Axis;rotationDegrees(F)Lorg/joml/Quaternionf;", ordinal = 2))
	private float shadowvisuals$hurtTilt(float degrees) {
		HurtCamera hurtCamera = Hooks.enabled(HurtCamera.class);
		return hurtCamera != null ? degrees * hurtCamera.strength() : degrees;
	}

	@ModifyExpressionValue(method = "bobView", at = @At(value = "INVOKE",
		target = "Lnet/minecraft/client/entity/ClientAvatarState;getInterpolatedBob(F)F"))
	private float shadowvisuals$bob(float bob) {
		ViewBobbing bobbing = Hooks.enabled(ViewBobbing.class);
		return bobbing != null ? bob * bobbing.strength() : bob;
	}

	@Inject(method = "getFov", at = @At("RETURN"), cancellable = true)
	private void shadowvisuals$fov(Camera camera, float partialTick, boolean useFovSetting, CallbackInfoReturnable<Float> cir) {
		float fov = cir.getReturnValueF();
		if (useFovSetting) {
			FovControl control = Hooks.enabled(FovControl.class);
			if (control != null) {
				fov = control.apply(fov, net.minecraft.client.Minecraft.getInstance().options.fov().get().floatValue());
			}
		}
		ShadowClient client = ShadowClient.get();
		Zoom zoom = client == null ? null : client.modules().get(Zoom.class);
		if (zoom != null) {
			float amount = zoom.amount();
			if (amount > 1.001f) {
				fov /= amount;
			}
		}
		cir.setReturnValue(Math.max(1f, Math.min(170f, fov)));
	}
}
