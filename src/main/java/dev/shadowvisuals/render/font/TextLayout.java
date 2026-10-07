package dev.shadowvisuals.render.font;

/**
 * Pre-measured glyph run of one string in em units. Layouts are cached by {@link FontManager}, so drawing the
 * same label every frame does no measuring or allocation.
 */
public final class TextLayout {
	final SdfFont.Glyph[] glyphs;
	final float[] offsets;
	final int count;
	final float width;
	final boolean complete;
	java.util.List<TextQuads.Page> pages;

	TextLayout(SdfFont.Glyph[] glyphs, float[] offsets, int count, float width, boolean complete) {
		this.glyphs = glyphs;
		this.offsets = offsets;
		this.count = count;
		this.width = width;
		this.complete = complete;
	}

	/** Width in em units; multiply by the font size. */
	public float width() {
		return width;
	}

	/** False when the font lacks a glyph; such strings are drawn with the vanilla font instead. */
	public boolean complete() {
		return complete;
	}

	static TextLayout build(SdfFont font, String text) {
		int length = text.length();
		SdfFont.Glyph[] glyphs = new SdfFont.Glyph[length];
		float[] offsets = new float[length];
		int count = 0;
		float cursor = 0;
		boolean complete = true;
		for (int i = 0; i < length; ) {
			int codePoint = text.codePointAt(i);
			i += Character.charCount(codePoint);
			if (codePoint == '§' && i < length) {
				// Skip legacy formatting codes such as "§a".
				i += Character.charCount(text.codePointAt(i));
				continue;
			}
			SdfFont.Glyph glyph = font.glyph(codePoint);
			if (glyph == null) {
				complete = false;
				continue;
			}
			glyphs[count] = glyph;
			offsets[count] = cursor;
			count++;
			cursor += glyph.advance();
		}
		return new TextLayout(glyphs, offsets, count, cursor, complete);
	}
}
