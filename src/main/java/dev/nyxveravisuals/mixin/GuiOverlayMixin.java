package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.client.gui.Gui;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.Entity;

import dev.nyxveravisuals.modules.Hooks;
import dev.nyxveravisuals.modules.visual.OverlayControl;

/** Overlay Control for 2D screen overlays drawn by the vanilla HUD. */
@Mixin(Gui.class)
public abstract class GuiOverlayMixin {
	@Inject(method = "renderVignette", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$vignette(GuiGraphics graphics, Entity entity, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control != null && control.vignette()) {
			ci.cancel();
		}
	}

	@Inject(method = "renderTextureOverlay", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$textureOverlay(GuiGraphics graphics, Identifier texture, float alpha, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control == null) {
			return;
		}
		String path = texture.getPath();
		if (control.powderSnow() && path.contains("powder_snow")) {
			ci.cancel();
		} else if (control.pumpkin() && path.contains("pumpkin")) {
			ci.cancel();
		}
	}

	@Inject(method = "renderPortalOverlay", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$portal(GuiGraphics graphics, float alpha, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control != null && control.portal()) {
			ci.cancel();
		}
	}

	@Inject(method = "renderConfusionOverlay", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$nausea(GuiGraphics graphics, float alpha, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control != null && control.nausea()) {
			ci.cancel();
		}
	}
}
