package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyArg;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;

import net.minecraft.client.Camera;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.camera.CameraSettings;
import dev.shadowvisuals.modules.camera.FreeLook;

/** Third-person distance and free-look camera rotation. */
@Mixin(Camera.class)
public abstract class CameraMixin {
	@ModifyArg(method = "setup", at = @At(value = "INVOKE", target = "Lnet/minecraft/client/Camera;getMaxZoom(F)F"))
	private float shadowvisuals$distance(float distance) {
		CameraSettings settings = Hooks.enabled(CameraSettings.class);
		return settings != null ? settings.distance(distance) : distance;
	}

	@WrapOperation(method = "setup", at = @At(value = "INVOKE", target = "Lnet/minecraft/client/Camera;setRotation(FF)V"))
	private void shadowvisuals$freeLook(Camera camera, float yaw, float pitch, Operation<Void> original) {
		FreeLook freeLook = Hooks.enabled(FreeLook.class);
		if (freeLook != null) {
			original.call(camera, freeLook.yaw(), freeLook.pitch());
		} else {
			original.call(camera, yaw, pitch);
		}
	}
}
