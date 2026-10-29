package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyArg;

import dev.nyxveravisuals.modules.Hooks;
import dev.nyxveravisuals.modules.iface.ChatVisuals;

/** Recolors chat line backgrounds in both chat drawing paths (closed and open chat). */
@Mixin(targets = {
	"net.minecraft.client.gui.components.ChatComponent$DrawingBackgroundGraphicsAccess",
	"net.minecraft.client.gui.components.ChatComponent$DrawingFocusedGraphicsAccess"
})
public abstract class ChatBackgroundMixin {
	@ModifyArg(method = "fill", at = @At(value = "INVOKE", target = "Lnet/minecraft/client/gui/GuiGraphics;fill(IIIII)V"), index = 4)
	private int nyxveravisuals$background(int color) {
		ChatVisuals visuals = Hooks.enabled(ChatVisuals.class);
		return visuals != null ? visuals.background(color) : color;
	}
}
