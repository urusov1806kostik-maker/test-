package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyVariable;

import net.minecraft.client.GuiMessageTag;
import net.minecraft.client.gui.components.ChatComponent;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MessageSignature;

import dev.nyxveravisuals.modules.Hooks;
import dev.nyxveravisuals.modules.iface.ChatVisuals;

/** Adds the display-only timestamp to incoming chat lines. */
@Mixin(ChatComponent.class)
public abstract class ChatComponentMixin {
	@ModifyVariable(method = "addMessage(Lnet/minecraft/network/chat/Component;Lnet/minecraft/network/chat/MessageSignature;Lnet/minecraft/client/GuiMessageTag;)V",
		at = @At("HEAD"), argsOnly = true, ordinal = 0)
	private Component nyxveravisuals$timestamp(Component message, Component same, MessageSignature signature, GuiMessageTag tag) {
		ChatVisuals visuals = Hooks.enabled(ChatVisuals.class);
		return visuals != null ? visuals.decorate(message) : message;
	}
}
