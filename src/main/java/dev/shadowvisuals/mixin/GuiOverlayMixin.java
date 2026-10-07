package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.client.gui.Gui;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.resources.Identifier;
import net.minecraft.world.entity.Entity;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.visual.OverlayControl;

/** Overlay Control for 2D screen overlays drawn by the vanilla HUD. */
@Mixin(Gui.class)
public abstract class GuiOverlayMixin {
	@Inject(method = "renderVignette", at = @At("HEAD"), cancellable = true)
	private void shadowvisuals$vignette(GuiGraphics graphics, Entity entity, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control != null && control.vignette()) {
			ci.cancel();
		}
	}

	@Inject(method = "renderTextureOverlay", at = @At("HEAD"), cancellable = true)
	private void shadowvisuals$textureOverlay(GuiGraphics graphics, Identifier texture, float alpha, CallbackInfo ci) {
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
	private void shadowvisuals$portal(GuiGraphics graphics, float alpha, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control != null && control.portal()) {
			ci.cancel();
		}
	}

	@Inject(method = "renderConfusionOverlay", at = @At("HEAD"), cancellable = true)
	private void shadowvisuals$nausea(GuiGraphics graphics, float alpha, CallbackInfo ci) {
		OverlayControl control = Hooks.enabled(OverlayControl.class);
		if (control != null && control.nausea()) {
			ci.cancel();
		}
	}
}
