package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.inventory.tooltip.TooltipRenderUtil;
import net.minecraft.resources.Identifier;

import dev.nyxveravisuals.modules.Hooks;
import dev.nyxveravisuals.modules.iface.CustomTooltips;

/** Custom Tooltips: replaces the vanilla tooltip frame for default-styled tooltips only. */
@Mixin(TooltipRenderUtil.class)
public abstract class TooltipRenderUtilMixin {
	@Inject(method = "renderTooltipBackground", at = @At("HEAD"), cancellable = true)
	private static void nyxveravisuals$background(GuiGraphics graphics, int x, int y, int width, int height, Identifier style, CallbackInfo ci) {
		if (style != null) {
			return;
		}
		CustomTooltips tooltips = Hooks.enabled(CustomTooltips.class);
		if (tooltips != null) {
			tooltips.drawBackground(graphics, x, y, width, height);
			ci.cancel();
		}
	}
}
