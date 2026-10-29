package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Final;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Shadow;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.client.KeyboardHandler;
import net.minecraft.client.Minecraft;
import net.minecraft.client.input.KeyEvent;

import dev.nyxveravisuals.NyxveraClient;

/** Forwards raw key input to the client (binds, GUI key). Only the press that opens the ClickGUI is consumed. */
@Mixin(KeyboardHandler.class)
public abstract class KeyboardHandlerMixin {
	@Shadow
	@Final
	private Minecraft minecraft;

	@Inject(method = "keyPress", at = @At("HEAD"), cancellable = true)
	private void nyxveravisuals$onKeyPress(long window, int action, KeyEvent event, CallbackInfo ci) {
		NyxveraClient client = NyxveraClient.get();
		if (client != null && window == minecraft.getWindow().handle()) {
			if (client.onKey(event.key(), event.scancode(), action, event.modifiers())) {
				ci.cancel();
			}
		}
	}
}
