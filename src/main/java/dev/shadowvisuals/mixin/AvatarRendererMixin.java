package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import net.minecraft.client.renderer.entity.player.AvatarRenderer;
import net.minecraft.world.entity.Avatar;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.visual.NameTags;

/** Hides vanilla player name tags while client name tags are shown. */
@Mixin(AvatarRenderer.class)
public abstract class AvatarRendererMixin {
	@Inject(method = "shouldShowName(Lnet/minecraft/world/entity/Avatar;D)Z", at = @At("HEAD"), cancellable = true)
	private void shadowvisuals$hideVanillaTag(Avatar avatar, double distance, CallbackInfoReturnable<Boolean> cir) {
		NameTags tags = Hooks.enabled(NameTags.class);
		if (tags != null && tags.hidesVanilla()) {
			cir.setReturnValue(false);
		}
	}
}
