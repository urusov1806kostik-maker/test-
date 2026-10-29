package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.client.Minecraft;
import net.minecraft.client.MouseHandler;
import net.minecraft.client.input.MouseButtonInfo;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.event.events.MouseScrollEvent;

/** Forwards mouse buttons (binds) and in-game scrolling (zoom) to the client. */
@Mixin(MouseHandler.class)
public abstract class MouseHandlerMixin {
	@Shadow
	@Final
	private Minecraft minecraft;

	@Inject(method = "onButton", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$onButton(long window, MouseButtonInfo info, int action, CallbackInfo ci) {
		NyxveraClient client = NyxveraClient.get();
		if (client != null && window == minecraft.getWindow().handle()) {
			if (client.onMouseButton(info.button(), action, info.modifiers())) {
				ci.cancel();
			}
		}
	}

	@Inject(method = "onScroll", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$onScroll(long window, double horizontal, double vertical, CallbackInfo ci) {
		NyxveraClient client = NyxveraClient.get();
		if (client == null || window != minecraft.getWindow().handle() || minecraft.screen != null || minecraft.level == null) {
			return;
		}
		if (client.events().post(new MouseScrollEvent(horizontal, vertical)).isCancelled()) {
			ci.cancel();
		}
	}
}
