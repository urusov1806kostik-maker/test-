package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.client.Camera;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.client.renderer.SkyRenderer;
import net.minecraft.client.renderer.state.SkyRenderState;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.world.SkyColor;

/** Sky Color: rewrites the extracted sky color of the render state. */
@Mixin(SkyRenderer.class)
public abstract class SkyRendererMixin {
	@Inject(method = "extractRenderState", at = @At("TAIL"))
	private void shadowvisuals$skyColor(ClientLevel level, float partialTick, Camera camera, SkyRenderState state, CallbackInfo ci) {
		SkyColor sky = Hooks.enabled(SkyColor.class);
		if (sky != null) {
			state.skyColor = sky.apply(state.skyColor);
		}
	}
}
