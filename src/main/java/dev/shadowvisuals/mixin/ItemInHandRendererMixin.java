package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import com.llamalad7.mixinextras.injector.wrapoperation.Operation;
import com.llamalad7.mixinextras.injector.wrapoperation.WrapOperation;
import com.mojang.blaze3d.vertex.PoseStack;

import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.ItemInHandRenderer;
import net.minecraft.client.renderer.SubmitNodeCollector;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.item.ItemStack;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.player.SwingAnimation;
import dev.shadowvisuals.modules.player.ViewModel;

/** View Model transforms and visual swing presets for first-person hands. */
@Mixin(ItemInHandRenderer.class)
public abstract class ItemInHandRendererMixin {
	@Inject(method = "renderArmWithItem", at = @At(value = "INVOKE",
		target = "Lnet/minecraft/client/renderer/ItemInHandRenderer;renderItem(Lnet/minecraft/world/entity/LivingEntity;Lnet/minecraft/world/item/ItemStack;Lnet/minecraft/world/item/ItemDisplayContext;Lcom/mojang/blaze3d/vertex/PoseStack;Lnet/minecraft/client/renderer/SubmitNodeCollector;I)V"))
	private void shadowvisuals$viewModel(AbstractClientPlayer player, float partialTick, float pitch, InteractionHand hand, float swing,
		ItemStack stack, float equip, PoseStack poses, SubmitNodeCollector collector, int light, CallbackInfo ci) {
		ViewModel viewModel = Hooks.enabled(ViewModel.class);
		if (viewModel != null) {
			viewModel.apply(poses, hand);
		}
	}

	@WrapOperation(method = "swingArm", at = @At(value = "INVOKE",
		target = "Lnet/minecraft/client/renderer/ItemInHandRenderer;applyItemArmAttackTransform(Lcom/mojang/blaze3d/vertex/PoseStack;Lnet/minecraft/world/entity/HumanoidArm;F)V"))
	private void shadowvisuals$swing(ItemInHandRenderer renderer, PoseStack poses, HumanoidArm arm, float progress, Operation<Void> original) {
		SwingAnimation swing = Hooks.enabled(SwingAnimation.class);
		if (swing != null) {
			swing.apply(poses, arm, progress);
		} else {
			original.call(renderer, poses, arm, progress);
		}
	}
}
