package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.client.DeltaTracker;
import net.minecraft.client.renderer.GameRenderer;

import dev.shadowvisuals.ShadowClient;

/** Advances the animation clock once per rendered frame, before world and GUI rendering. */
@Mixin(GameRenderer.class)
public abstract class GameRendererMixin {
	@Inject(method = "render", at = @At("HEAD"))
	private void shadowvisuals$onFrameStart(DeltaTracker deltaTracker, boolean renderLevel, CallbackInfo ci) {
		ShadowClient client = ShadowClient.get();
		if (client != null) {
			client.onFrameStart();
		}
	}
}
