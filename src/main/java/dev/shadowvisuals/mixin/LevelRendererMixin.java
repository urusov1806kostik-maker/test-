package dev.shadowvisuals.mixin;

import org.joml.Matrix4f;
import org.joml.Vector4f;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

import com.mojang.blaze3d.buffers.GpuBufferSlice;
import com.mojang.blaze3d.resource.GraphicsResourceAllocator;

import net.minecraft.client.Camera;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.renderer.LevelRenderer;

import dev.shadowvisuals.ShadowClient;

/** Captures the exact view/projection matrices of the world frame for world-to-screen projection. */
@Mixin(LevelRenderer.class)
public abstract class LevelRendererMixin {
	@Inject(method = "renderLevel", at = @At("HEAD"))
	private void shadowvisuals$captureMatrices(GraphicsResourceAllocator allocator, DeltaTracker deltaTracker, boolean renderBlockOutline,
		Camera camera, Matrix4f modelView, Matrix4f projection, Matrix4f cullProjection, GpuBufferSlice fog, Vector4f fogColor,
		boolean renderSky, CallbackInfo ci) {
		ShadowClient client = ShadowClient.get();
		if (client != null) {
			client.projection().capture(modelView, projection, camera.position());
		}
	}
}
