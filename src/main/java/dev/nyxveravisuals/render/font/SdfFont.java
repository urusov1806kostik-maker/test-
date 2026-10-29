package dev.nyxveravisuals.render.font;

import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

import org.lwjgl.PointerBuffer;
import org.lwjgl.system.MemoryStack;
import org.lwjgl.system.MemoryUtil;
import org.lwjgl.util.freetype.FT_Bitmap;
import org.lwjgl.util.freetype.FT_Face;
import org.lwjgl.util.freetype.FT_GlyphSlot;
import org.lwjgl.util.freetype.FreeType;

import com.mojang.blaze3d.platform.TextureUtil;

import it.unimi.dsi.fastutil.ints.Int2ObjectOpenHashMap;

import net.minecraft.client.gui.font.providers.FreeTypeUtil;

import dev.nyxveravisuals.core.Log;

/**
 * A TrueType face rasterized on demand into signed-distance-field glyphs (FreeType's SDF renderer).
 * Metrics are expressed in em units, so callers multiply by the desired font size.
 */
public final class SdfFont implements AutoCloseable {
	/** Rasterization size of one em in pixels; distance fields scale well far below and above this. */
	static final int EM_PIXELS = 32;

	/** Placeholder stored for code points the face does not contain. */
	private static final Glyph MISSING = new Glyph(0, 0, 0, 0, 0, 0, 0, 0, 0, null);

	public record Glyph(float advance, float left, float top, float width, float height,
		float u0, float v0, float u1, float v1, GlyphAtlas atlas) {
		boolean visible() {
			return atlas != null;
		}
	}

	private final String name;
	private final ByteBuffer data;
	private FT_Face face;
	private final float ascender;
	private final float descender;
	private final float capHeight;
	private final float ascenderPixels;
	private final Int2ObjectOpenHashMap<Glyph> glyphs = new Int2ObjectOpenHashMap<>();
	private final List<GlyphAtlas> atlases = new ArrayList<>();

	private SdfFont(String name, ByteBuffer data, FT_Face face) {
		this.name = name;
		this.data = data;
		this.face = face;
		FreeType.FT_Set_Pixel_Sizes(face, 0, EM_PIXELS);
		this.ascenderPixels = face.size().metrics().ascender() / 64f;
		this.ascender = ascenderPixels / EM_PIXELS;
		this.descender = -face.size().metrics().descender() / 64f / EM_PIXELS;
		float cap = 0.72f;
		int index = FreeType.FT_Get_Char_Index(face, 'H');
		if (index != 0 && FreeType.FT_Load_Glyph(face, index, FreeType.FT_LOAD_DEFAULT) == 0) {
			cap = face.glyph().metrics().horiBearingY() / 64f / EM_PIXELS;
		}
		this.capHeight = cap;
	}

	/** Loads a TTF from the mod jar. Throws if the file is missing or not a valid font. */
	public static SdfFont load(String name, String classpathResource) throws IOException {
		ByteBuffer buffer;
		try (InputStream stream = SdfFont.class.getResourceAsStream(classpathResource)) {
			if (stream == null) {
				throw new IOException("Font resource not found: " + classpathResource);
			}
			buffer = TextureUtil.readResource(stream);
		}
		synchronized (FreeTypeUtil.LIBRARY_LOCK) {
			try (MemoryStack stack = MemoryStack.stackPush()) {
				PointerBuffer pointer = stack.mallocPointer(1);
				int error = FreeType.FT_New_Memory_Face(FreeTypeUtil.getLibrary(), buffer, 0L, pointer);
				if (error != 0) {
					MemoryUtil.memFree(buffer);
					throw new IOException("FreeType could not open " + classpathResource + " (error " + error + ")");
				}
				FT_Face face = FT_Face.create(pointer.get(0));
				FreeType.FT_Select_Charmap(face, FreeType.FT_ENCODING_UNICODE);
				return new SdfFont(name, buffer, face);
			}
		}
	}

	public float ascender() {
		return ascender;
	}

	public float descender() {
		return descender;
	}

	public float lineHeight() {
		return ascender + descender;
	}

	public float capHeight() {
		return capHeight;
	}

	/** Returns the glyph or {@code null} if this face has no glyph for the code point. */
	public Glyph glyph(int codePoint) {
		Glyph glyph = glyphs.get(codePoint);
		if (glyph == null) {
			glyph = rasterize(codePoint);
			glyphs.put(codePoint, glyph);
		}
		return glyph == MISSING ? null : glyph;
	}

	private Glyph rasterize(int codePoint) {
		if (face == null) {
			return MISSING;
		}
		synchronized (FreeTypeUtil.LIBRARY_LOCK) {
			int index = FreeType.FT_Get_Char_Index(face, codePoint);
			if (index == 0) {
				return MISSING;
			}
			if (FreeType.FT_Load_Glyph(face, index, FreeType.FT_LOAD_DEFAULT) != 0) {
				return MISSING;
			}
			FT_GlyphSlot slot = face.glyph();
			float advance = slot.advance().x() / 64f / EM_PIXELS;
			if (slot.metrics().width() == 0 || slot.metrics().height() == 0) {
				return new Glyph(advance, 0, 0, 0, 0, 0, 0, 0, 0, null);
			}
			if (FreeType.FT_Render_Glyph(slot, FreeType.FT_RENDER_MODE_SDF) != 0) {
				Log.warnOnce("sdf:" + name + ":" + codePoint, "Could not render glyph U+{} of {}", Integer.toHexString(codePoint), name);
				return MISSING;
			}
			FT_Bitmap bitmap = slot.bitmap();
			int width = bitmap.width();
			int height = bitmap.rows();
			int pitch = bitmap.pitch();
			if (width <= 0 || height <= 0) {
				return new Glyph(advance, 0, 0, 0, 0, 0, 0, 0, 0, null);
			}
			int[] position = null;
			GlyphAtlas atlas = atlases.isEmpty() ? null : atlases.get(atlases.size() - 1);
			if (atlas != null) {
				position = atlas.allocate(width, height);
			}
			if (position == null) {
				atlas = new GlyphAtlas("nyxveravisuals:font/" + name + "/" + atlases.size());
				atlases.add(atlas);
				position = atlas.allocate(width, height);
				if (position == null) {
					return MISSING;
				}
			}
			ByteBuffer pixels = bitmap.buffer(Math.abs(pitch) * height);
			for (int row = 0; row < height; row++) {
				int source = pitch >= 0 ? row * pitch : (height - 1 - row) * -pitch;
				for (int column = 0; column < width; column++) {
					atlas.setDistance(position[0] + column, position[1] + row, pixels.get(source + column) & 0xFF);
				}
			}
			float size = GlyphAtlas.SIZE;
			return new Glyph(
				advance,
				slot.bitmap_left() / (float) EM_PIXELS,
				(ascenderPixels - slot.bitmap_top()) / EM_PIXELS,
				width / (float) EM_PIXELS,
				height / (float) EM_PIXELS,
				position[0] / size,
				position[1] / size,
				(position[0] + width) / size,
				(position[1] + height) / size,
				atlas);
		}
	}

	/** Pushes newly rasterized glyphs to the GPU; called once per frame before drawing. */
	public void uploadPending() {
		for (GlyphAtlas atlas : atlases) {
			atlas.uploadIfDirty();
		}
	}

	@Override
	public void close() {
		synchronized (FreeTypeUtil.LIBRARY_LOCK) {
			if (face != null) {
				FreeType.FT_Done_Face(face);
				face = null;
			}
		}
		MemoryUtil.memFree(data);
		for (GlyphAtlas atlas : atlases) {
			atlas.close();
		}
		atlases.clear();
		glyphs.clear();
	}
}
