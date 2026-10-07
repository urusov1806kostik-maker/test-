package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyArg;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.iface.ChatVisuals;

/** Recolors chat line backgrounds in both chat drawing paths (closed and open chat). */
@Mixin(targets = {
	"net.minecraft.client.gui.components.ChatComponent$DrawingBackgroundGraphicsAccess",
	"net.minecraft.client.gui.components.ChatComponent$DrawingFocusedGraphicsAccess"
})
public abstract class ChatBackgroundMixin {
	@ModifyArg(method = "fill", at = @At(value = "INVOKE", target = "Lnet/minecraft/client/gui/GuiGraphics;fill(IIIII)V"), index = 4)
	private int shadowvisuals$background(int color) {
		ChatVisuals visuals = Hooks.enabled(ChatVisuals.class);
		return visuals != null ? visuals.background(color) : color;
	}
}
