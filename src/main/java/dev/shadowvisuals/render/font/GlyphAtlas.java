package dev.shadowvisuals.render.font;

import com.mojang.blaze3d.platform.NativeImage;
import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.textures.FilterMode;

import net.minecraft.client.gui.render.TextureSetup;
import net.minecraft.client.renderer.texture.DynamicTexture;

/**
 * One 1024² page of distance-field glyphs packed in shelves. Pixels are white with the distance in alpha,
 * sampled with linear filtering so text stays smooth at any scale. Uploads are batched per frame.
 */
final class GlyphAtlas implements AutoCloseable {
	static final int SIZE = 1024;
	private static final int PADDING = 2;

	private final NativeImage image;
	private final DynamicTexture texture;
	private TextureSetup textureSetup;
	private int cursorX = PADDING;
	private int cursorY = PADDING;
	private int rowHeight;
	private boolean dirty;

	GlyphAtlas(String label) {
		this.image = new NativeImage(NativeImage.Format.RGBA, SIZE, SIZE, true);
		this.texture = new DynamicTexture(() -> label, image);
	}

	/** Reserves space; returns {@code {x, y}} or {@code null} when the page is full. */
	int[] allocate(int width, int height) {
		if (width + PADDING * 2 > SIZE || height + PADDING * 2 > SIZE) {
			return null;
		}
		if (cursorX + width + PADDING > SIZE) {
			cursorX = PADDING;
			cursorY += rowHeight + PADDING;
			rowHeight = 0;
		}
		if (cursorY + height + PADDING > SIZE) {
			return null;
		}
		int[] position = {cursorX, cursorY};
		cursorX += width + PADDING;
		rowHeight = Math.max(rowHeight, height);
		return position;
	}

	void setDistance(int x, int y, int distance) {
		image.setPixel(x, y, (distance << 24) | 0x00FFFFFF);
		dirty = true;
	}

	void uploadIfDirty() {
		if (dirty) {
			texture.upload();
			dirty = false;
		}
	}

	TextureSetup textureSetup() {
		if (textureSetup == null) {
			textureSetup = TextureSetup.singleTexture(texture.getTextureView(), RenderSystem.getSamplerCache().getClampToEdge(FilterMode.LINEAR));
		}
		return textureSetup;
	}

	@Override
	public void close() {
		texture.close();
	}
}
