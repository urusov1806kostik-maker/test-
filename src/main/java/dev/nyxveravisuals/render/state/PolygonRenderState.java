package dev.nyxveravisuals.render.state;

import org.joml.Matrix3x2f;
import org.jspecify.annotations.Nullable;

import com.mojang.blaze3d.pipeline.RenderPipeline;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.gui.navigation.ScreenRectangle;
import net.minecraft.client.gui.render.TextureSetup;
import net.minecraft.client.gui.render.state.GuiElementRenderState;
import net.minecraft.client.renderer.RenderPipelines;

/**
 * Filled triangle fan around a center point (stars, arrows, pie segments), emitted as degenerate quads so
 * it batches with the vanilla GUI pipeline. Edges are smoothed by drawing an anti-aliased outline on top.
 */
public record PolygonRenderState(
	Matrix3x2f pose,
	float centerX,
	float centerY,
	float[] ring,
	int color,
	@Nullable ScreenRectangle scissorArea,
	@Nullable ScreenRectangle bounds
) implements GuiElementRenderState {
	public static PolygonRenderState create(Matrix3x2f pose, float centerX, float centerY, float[] ring, int color, @Nullable ScreenRectangle scissor) {
		float minX = centerX;
		float minY = centerY;
		float maxX = centerX;
		float maxY = centerY;
		for (int i = 0; i + 1 < ring.length; i += 2) {
			minX = Math.min(minX, ring[i]);
			maxX = Math.max(maxX, ring[i]);
			minY = Math.min(minY, ring[i + 1]);
			maxY = Math.max(maxY, ring[i + 1]);
		}
		ScreenRectangle area = new ScreenRectangle((int) Math.floor(minX), (int) Math.floor(minY),
			(int) Math.ceil(maxX - minX) + 1, (int) Math.ceil(maxY - minY) + 1).transformMaxBounds(pose);
		return new PolygonRenderState(pose, centerX, centerY, ring, color, scissor, scissor != null ? scissor.intersection(area) : area);
	}

	@Override
	public void buildVertices(VertexConsumer consumer) {
		int points = ring.length / 2;
		for (int i = 0; i < points; i++) {
			int next = (i + 1) % points;
			float ax = ring[i * 2];
			float ay = ring[i * 2 + 1];
			float bx = ring[next * 2];
			float by = ring[next * 2 + 1];
			// GUI pipelines cull back faces: keep the same winding as vanilla quads (negative cross in screen space).
			float cross = (ax - centerX) * (by - centerY) - (ay - centerY) * (bx - centerX);
			if (cross > 0) {
				float swapX = ax;
				float swapY = ay;
				ax = bx;
				ay = by;
				bx = swapX;
				by = swapY;
			}
			consumer.addVertexWith2DPose(pose, centerX, centerY).setColor(color);
			consumer.addVertexWith2DPose(pose, ax, ay).setColor(color);
			consumer.addVertexWith2DPose(pose, bx, by).setColor(color);
			consumer.addVertexWith2DPose(pose, bx, by).setColor(color);
		}
	}

	@Override
	public RenderPipeline pipeline() {
		return RenderPipelines.GUI;
	}

	@Override
	public TextureSetup textureSetup() {
		return TextureSetup.noTexture();
	}
}
