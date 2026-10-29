package dev.nyxveravisuals.render.state;

import org.joml.Matrix3x2f;
import org.jspecify.annotations.Nullable;

import com.mojang.blaze3d.pipeline.RenderPipeline;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.gui.navigation.ScreenRectangle;
import net.minecraft.client.gui.render.TextureSetup;
import net.minecraft.client.gui.render.state.GuiElementRenderState;

import dev.nyxveravisuals.render.NyxveraPipelines;

/**
 * One analytic shape (rounded rectangle, outline or soft shadow) rendered by the {@code ui_shape} shader.
 * Coordinates are floats so animated elements move smoothly instead of snapping to whole GUI units.
 */
public record ShapeRenderState(
	Matrix3x2f pose,
	float x0,
	float y0,
	float x1,
	float y1,
	float expand,
	int colorTopLeft,
	int colorBottomLeft,
	int colorBottomRight,
	int colorTopRight,
	float radius,
	float mode,
	@Nullable ScreenRectangle scissorArea,
	@Nullable ScreenRectangle bounds
) implements GuiElementRenderState {
	private static final float PACK = 8f;
	private static final int MAX_PACKED = Short.MAX_VALUE;

	public static ShapeRenderState create(Matrix3x2f pose, float x0, float y0, float x1, float y1, float expand,
		int topLeft, int bottomLeft, int bottomRight, int topRight, float radius, float mode, @Nullable ScreenRectangle scissor) {
		ScreenRectangle area = new ScreenRectangle(
			(int) Math.floor(x0 - expand), (int) Math.floor(y0 - expand),
			(int) Math.ceil(x1 - x0 + expand * 2) + 1, (int) Math.ceil(y1 - y0 + expand * 2) + 1).transformMaxBounds(pose);
		ScreenRectangle bounds = scissor != null ? scissor.intersection(area) : area;
		return new ShapeRenderState(pose, x0, y0, x1, y1, expand, topLeft, bottomLeft, bottomRight, topRight, radius, mode, scissor, bounds);
	}

	private static int pack(float value) {
		int packed = Math.round(value * PACK);
		return Math.max(-MAX_PACKED, Math.min(MAX_PACKED, packed));
	}

	@Override
	public void buildVertices(VertexConsumer consumer) {
		float centerX = (x0 + x1) * 0.5f;
		float centerY = (y0 + y1) * 0.5f;
		int halfWidth = pack((x1 - x0) * 0.5f);
		int halfHeight = pack((y1 - y0) * 0.5f);
		int packedRadius = pack(radius);
		int packedMode = pack(mode);
		float left = x0 - expand;
		float top = y0 - expand;
		float right = x1 + expand;
		float bottom = y1 + expand;
		consumer.addVertexWith2DPose(pose, left, top).setColor(colorTopLeft)
			.setUv(left - centerX, top - centerY).setUv1(halfWidth, halfHeight).setUv2(packedRadius, packedMode);
		consumer.addVertexWith2DPose(pose, left, bottom).setColor(colorBottomLeft)
			.setUv(left - centerX, bottom - centerY).setUv1(halfWidth, halfHeight).setUv2(packedRadius, packedMode);
		consumer.addVertexWith2DPose(pose, right, bottom).setColor(colorBottomRight)
			.setUv(right - centerX, bottom - centerY).setUv1(halfWidth, halfHeight).setUv2(packedRadius, packedMode);
		consumer.addVertexWith2DPose(pose, right, top).setColor(colorTopRight)
			.setUv(right - centerX, top - centerY).setUv1(halfWidth, halfHeight).setUv2(packedRadius, packedMode);
	}

	@Override
	public RenderPipeline pipeline() {
		return NyxveraPipelines.UI_SHAPE;
	}

	@Override
	public TextureSetup textureSetup() {
		return TextureSetup.noTexture();
	}
}
