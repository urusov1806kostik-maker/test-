package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;

import net.minecraft.client.MouseHandler;
import net.minecraft.client.player.LocalPlayer;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.camera.FreeLook;
import dev.shadowvisuals.modules.camera.Zoom;

/** Routes mouse look to free-look and scales sensitivity while zoomed. */
@Mixin(MouseHandler.class)
public abstract class MouseTurnMixin {
	@WrapOperation(method = "turnPlayer", at = @At(value = "INVOKE", target = "Lnet/minecraft/client/player/LocalPlayer;turn(DD)V"))
	private void shadowvisuals$turn(LocalPlayer player, double yaw, double pitch, Operation<Void> original) {
		Zoom zoom = Hooks.enabled(Zoom.class);
		if (zoom != null && zoom.scalesSensitivity()) {
			float amount = zoom.amount();
			yaw /= amount;
			pitch /= amount;
		}
		FreeLook freeLook = Hooks.enabled(FreeLook.class);
		if (freeLook != null) {
			freeLook.turn(yaw, pitch);
			return;
		}
		original.call(player, yaw, pitch);
	}
}
