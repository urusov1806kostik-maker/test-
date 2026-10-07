package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import net.minecraft.client.multiplayer.ClientLevel;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.world.TimeChanger;

/** Client-only day time override for Time Changer. */
@Mixin(ClientLevel.ClientLevelData.class)
public abstract class ClientLevelDataMixin {
	@Inject(method = "getDayTime", at = @At("RETURN"), cancellable = true)
	private void shadowvisuals$dayTime(CallbackInfoReturnable<Long> cir) {
		TimeChanger changer = Hooks.enabled(TimeChanger.class);
		if (changer != null) {
			cir.setReturnValue(changer.dayTime(cir.getReturnValueJ()));
		}
	}
}
