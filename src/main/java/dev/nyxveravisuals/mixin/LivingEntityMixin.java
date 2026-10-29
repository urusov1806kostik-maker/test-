package dev.nyxveravisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.world.entity.EntityEvent;
import net.minecraft.world.entity.LivingEntity;

import dev.nyxveravisuals.NyxveraClient;

/** Counts totem pops for the Target HUD from the entity event every nearby client receives. */
@Mixin(LivingEntity.class)
public abstract class LivingEntityMixin {
	@Inject(method = "handleEntityEvent", at = @At("HEAD"))
	private void nyxveravisuals$totemPop(byte event, CallbackInfo ci) {
		LivingEntity self = (LivingEntity) (Object) this;
		if (event == EntityEvent.PROTECTED_FROM_DEATH && self.level().isClientSide()) {
			NyxveraClient client = NyxveraClient.get();
			if (client != null) {
				client.combat().onTotemPop(self);
			}
		}
	}
}
