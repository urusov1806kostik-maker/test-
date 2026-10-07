package dev.shadowvisuals.render.state;

import org.joml.Matrix3x2f;
import org.jspecify.annotations.Nullable;

import com.mojang.blaze3d.pipeline.RenderPipeline;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.gui.navigation.ScreenRectangle;
import net.minecraft.client.gui.render.TextureSetup;
import net.minecraft.client.gui.render.state.GuiElementRenderState;

import dev.shadowvisuals.render.ShadowPipelines;
import dev.shadowvisuals.render.font.TextLayout;
import dev.shadowvisuals.render.font.TextQuads;

/** Distance-field text run on one glyph atlas page. Positions are floats for sub-pixel animation. */
public record SdfTextRenderState(
	Matrix3x2f pose,
	TextLayout layout,
	Object atlas,
	TextureSetup textureSetup,
	float x,
	float y,
	float size,
	int color,
	@Nullable ScreenRectangle scissorArea,
	@Nullable ScreenRectangle bounds
) implements GuiElementRenderState {
	@Override
	public void buildVertices(VertexConsumer consumer) {
		TextQuads.emit(layout, atlas, x, y, size, (x0, y0, x1, y1, u0, v0, u1, v1) -> {
			consumer.addVertexWith2DPose(pose, x0, y0).setUv(u0, v0).setColor(color);
			consumer.addVertexWith2DPose(pose, x0, y1).setUv(u0, v1).setColor(color);
			consumer.addVertexWith2DPose(pose, x1, y1).setUv(u1, v1).setColor(color);
			consumer.addVertexWith2DPose(pose, x1, y0).setUv(u1, v0).setColor(color);
		});
	}

	@Override
	public RenderPipeline pipeline() {
		return ShadowPipelines.SDF_TEXT;
	}
}
