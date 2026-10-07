package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;

import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.world.entity.Entity;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.visual.PlayerEsp;

/** Player ESP outline: reuses the vanilla glowing-outline pass with the ESP color. */
@Mixin(EntityRenderer.class)
public abstract class EntityRendererMixin {
	@WrapOperation(method = "extractRenderState", at = @At(value = "INVOKE",
		target = "Lnet/minecraft/client/Minecraft;shouldEntityAppearGlowing(Lnet/minecraft/world/entity/Entity;)Z"))
	private boolean shadowvisuals$glow(Minecraft minecraft, Entity entity, Operation<Boolean> original) {
		PlayerEsp esp = Hooks.enabled(PlayerEsp.class);
		if (esp != null && esp.outline() && esp.targets(entity)) {
			return true;
		}
		return original.call(minecraft, entity);
	}

	@WrapOperation(method = "extractRenderState", at = @At(value = "INVOKE", target = "Lnet/minecraft/world/entity/Entity;getTeamColor()I"))
	private int shadowvisuals$glowColor(Entity entity, Operation<Integer> original) {
		PlayerEsp esp = Hooks.enabled(PlayerEsp.class);
		if (esp != null && esp.outline() && esp.targets(entity)) {
			return esp.colorFor(entity) & 0xFFFFFF;
		}
		return original.call(entity);
	}
}
