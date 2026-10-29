package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import com.mojang.blaze3d.vertex.PoseStack;

import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.ScreenEffectRenderer;
import net.minecraft.client.renderer.texture.TextureAtlasSprite;

import dev.nyxveravisuals.modules.Hooks;
import dev.nyxveravisuals.modules.visual.FireOverlay;
import dev.nyxveravisuals.modules.visual.OverlayControl;

/** Fire overlay height/visibility and in-block / underwater overlays. */
@Mixin(ScreenEffectRenderer.class)
public abstract class ScreenEffectRendererMixin {
	@Inject(method = "renderFire", at = @At("HEAD"), cancellable = true)
	private static void nyxveravisuals$fire(PoseStack poses, MultiBufferSource buffers, TextureAtlasSprite sprite, CallbackInfo ci) {
		FireOverlay fire = Hooks.enabled(FireOverlay.class);
		if (fire == null) {
			return;
		}
		if (fire.hide()) {
			ci.cancel();
			return;
		}
		poses.translate(0, -fire.offset(), 0);
	}

	@Inject(method = "renderTex", at = @At("HEAD"), cancellable = true)
	private static void nyxveravisuals$inBlock(TextureAtlasSprite sprite, PoseStack poses, MultiBufferSource buffers, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control != null && control.blockInside()) {
			ci.cancel();
		}
	}

	@Inject(method = "renderWater", at = @At("HEAD"), cancellable = true)
	private static void nyxveravisuals$water(net.minecraft.client.Minecraft minecraft, PoseStack poses, MultiBufferSource buffers, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control != null && control.water()) {
			ci.cancel();
		}
	}
}
