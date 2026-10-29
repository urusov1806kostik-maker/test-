package dev.nyxveravisuals.render.font;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.renderer.MultiBufferSource;

import dev.nyxveravisuals.render.NyxveraPipelines;

/** Draws client-font text into world buffers in the current pose (x right, y down, in font units). */
public final class WorldText {
	private WorldText() {
	}

	/** True when {@code text} can be drawn with the custom font; otherwise callers use the vanilla font. */
	public static boolean canDraw(FontManager fonts, String text, FontManager.Weight weight) {
		if (!NyxveraPipelines.worldTextAvailable()) {
			return false;
		}
		TextLayout layout = fonts.layout(text, weight);
		return layout != null && layout.complete();
	}

	/** Width of {@code text} at {@code size} font units. Only meaningful after {@link #canDraw} returned true. */
	public static float width(FontManager fonts, String text, float size, FontManager.Weight weight) {
		TextLayout layout = fonts.layout(text, weight);
		return layout == null ? 0 : layout.width() * size;
	}

	/** Emits {@code text} with its top-left at {@code (x, y)}; call {@link #canDraw} first. */
	public static void draw(FontManager fonts, MultiBufferSource buffers, PoseStack.Pose pose, String text, float x, float y, float size,
		FontManager.Weight weight, int color, boolean seeThrough) {
		TextLayout layout = fonts.layout(text, weight);
		if (layout == null) {
			return;
		}
		for (TextQuads.Page page : TextQuads.pages(layout)) {
			GlyphAtlas atlas = (GlyphAtlas) page.atlas();
			VertexConsumer consumer = buffers.getBuffer(atlas.worldType(seeThrough));
			TextQuads.emit(layout, atlas, x, y, size, (x0, y0, x1, y1, u0, v0, u1, v1) -> {
				consumer.addVertex(pose, x0, y0, 0).setUv(u0, v0).setColor(color);
				consumer.addVertex(pose, x0, y1, 0).setUv(u0, v1).setColor(color);
				consumer.addVertex(pose, x1, y1, 0).setUv(u1, v1).setColor(color);
				consumer.addVertex(pose, x1, y0, 0).setUv(u1, v0).setColor(color);
			});
		}
	}
}
