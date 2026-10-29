package dev.nyxveravisuals.mixin;

import org.joml.Vector3fc;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyArg;

import net.minecraft.client.renderer.LightTexture;

import dev.nyxveravisuals.modules.Hooks;
import dev.nyxveravisuals.modules.visual.FullBright;
import dev.nyxveravisuals.modules.world.AmbientColor;
import dev.nyxveravisuals.modules.world.WorldColor;

/** Adjusts lightmap uniforms (night vision, brightness, sky light and ambient tint) without touching options. */
@Mixin(LightTexture.class)
public abstract class LightTextureMixin {
	private static final String PUT_FLOAT = "Lcom/mojang/blaze3d/buffers/Std140Builder;putFloat(F)Lcom/mojang/blaze3d/buffers/Std140Builder;";
	private static final String PUT_VEC3 = "Lcom/mojang/blaze3d/buffers/Std140Builder;putVec3(Lorg/joml/Vector3fc;)Lcom/mojang/blaze3d/buffers/Std140Builder;";

	@ModifyArg(method = "updateLightTexture", at = @At(value = "INVOKE", target = PUT_FLOAT, ordinal = 3))
	private float nyxveravisuals$nightVision(float value) {
		FullBright fullBright = Hooks.enabled(FullBright.class);
		return fullBright != null ? fullBright.nightVision(value) : value;
	}

	@ModifyArg(method = "updateLightTexture", at = @At(value = "INVOKE", target = PUT_FLOAT, ordinal = 6))
	private float nyxveravisuals$brightness(float value) {
		FullBright fullBright = Hooks.enabled(FullBright.class);
		return fullBright != null ? fullBright.brightness(value) : value;
	}

	@ModifyArg(method = "updateLightTexture", at = @At(value = "INVOKE", target = PUT_VEC3, ordinal = 0))
	private Vector3fc nyxveravisuals$skyLightColor(Vector3fc value) {
		WorldColor worldColor = Hooks.enabled(WorldColor.class);
		return worldColor != null ? worldColor.tint(value) : value;
	}

	@ModifyArg(method = "updateLightTexture", at = @At(value = "INVOKE", target = PUT_VEC3, ordinal = 1))
	private Vector3fc nyxveravisuals$ambientTint(Vector3fc value) {
		AmbientColor ambient = Hooks.enabled(AmbientColor.class);
		return ambient != null ? ambient.tint(value) : value;
	}
}
