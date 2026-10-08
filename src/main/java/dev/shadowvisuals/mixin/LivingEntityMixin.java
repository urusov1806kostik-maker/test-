package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import net.minecraft.world.entity.EntityEvent;
import net.minecraft.world.entity.LivingEntity;

import dev.shadowvisuals.ShadowClient;

/** Counts totem pops for the Target HUD from the entity event every nearby client receives. */
@Mixin(LivingEntity.class)
public abstract class LivingEntityMixin {
	@Inject(method = "handleEntityEvent", at = @At("HEAD"))
	private void shadowvisuals$totemPop(byte event, CallbackInfo ci) {
		LivingEntity self = (LivingEntity) (Object) this;
		if (event == EntityEvent.PROTECTED_FROM_DEATH && self.level().isClientSide()) {
			ShadowClient client = ShadowClient.get();
			if (client != null) {
				client.combat().onTotemPop(self);
			}
		}
	}
}
