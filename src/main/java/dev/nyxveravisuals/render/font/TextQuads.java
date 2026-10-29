package dev.nyxveravisuals.render.font;

import java.util.ArrayList;
import java.util.List;

import net.minecraft.client.gui.render.TextureSetup;

/** Bridges cached layouts to render states without exposing font internals. */
public final class TextQuads {
	@FunctionalInterface
	public interface QuadSink {
		void quad(float x0, float y0, float x1, float y1, float u0, float v0, float u1, float v1);
	}

	public record Page(Object atlas, TextureSetup textureSetup) {
	}

	private TextQuads() {
	}

	/** Emits the glyph quads of {@code layout} that live on {@code atlas}. */
	public static void emit(TextLayout layout, Object atlas, float x, float y, float size, QuadSink sink) {
		for (int i = 0; i < layout.count; i++) {
			SdfFont.Glyph glyph = layout.glyphs[i];
			if (!glyph.visible() || glyph.atlas() != atlas) {
				continue;
			}
			float x0 = x + (layout.offsets[i] + glyph.left()) * size;
			float y0 = y + glyph.top() * size;
			sink.quad(x0, y0, x0 + glyph.width() * size, y0 + glyph.height() * size, glyph.u0(), glyph.v0(), glyph.u1(), glyph.v1());
		}
	}

	/** Atlas pages used by a layout (almost always one); computed once and cached on the layout. */
	public static List<Page> pages(TextLayout layout) {
		if (layout.pages != null) {
			return layout.pages;
		}
		List<Page> pages = new ArrayList<>(1);
		GlyphAtlas last = null;
		for (int i = 0; i < layout.count; i++) {
			GlyphAtlas atlas = layout.glyphs[i].atlas();
			if (atlas == null || atlas == last) {
				continue;
			}
			last = atlas;
			boolean known = false;
			for (Page page : pages) {
				if (page.atlas() == atlas) {
					known = true;
					break;
				}
			}
			if (!known) {
				pages.add(new Page(atlas, atlas.textureSetup()));
			}
		}
		layout.pages = List.copyOf(pages);
		return layout.pages;
	}
}
