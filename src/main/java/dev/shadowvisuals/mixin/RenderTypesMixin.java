package dev.shadowvisuals.mixin;

import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.rendertype.RenderTypes;

import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.visual.GlintColor;

/** Swaps the enchantment glint render types for tinted copies while Glint Color is on. */
@Mixin(RenderTypes.class)
public abstract class RenderTypesMixin {
	@Unique
	private static void shadowvisuals$replace(int kind, CallbackInfoReturnable<RenderType> cir) {
		GlintColor module = Hooks.enabled(GlintColor.class);
		if (module != null) {
			RenderType replacement = module.replacement(kind);
			if (replacement != null) {
				cir.setReturnValue(replacement);
			}
		}
	}

	@Inject(method = "glint", at = @At("HEAD"), cancellable = true)
	private static void shadowvisuals$glint(CallbackInfoReturnable<RenderType> cir) {
		shadowvisuals$replace(0, cir);
	}

	@Inject(method = "glintTranslucent", at = @At("HEAD"), cancellable = true)
	private static void shadowvisuals$glintTranslucent(CallbackInfoReturnable<RenderType> cir) {
		shadowvisuals$replace(1, cir);
	}

	@Inject(method = "entityGlint", at = @At("HEAD"), cancellable = true)
	private static void shadowvisuals$entityGlint(CallbackInfoReturnable<RenderType> cir) {
		shadowvisuals$replace(2, cir);
	}

	@Inject(method = "armorEntityGlint", at = @At("HEAD"), cancellable = true)
	private static void shadowvisuals$armorEntityGlint(CallbackInfoReturnable<RenderType> cir) {
		shadowvisuals$replace(3, cir);
	}
}
