package dev.shadowvisuals.render.font;

import com.mojang.blaze3d.platform.NativeImage;
import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.textures.FilterMode;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.render.TextureSetup;
import net.minecraft.client.renderer.rendertype.RenderSetup;
import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.texture.DynamicTexture;
import net.minecraft.resources.Identifier;

import dev.shadowvisuals.render.ShadowPipelines;

/**
 * One 1024² page of distance-field glyphs packed in shelves. Pixels are white with the distance in alpha,
 * sampled with linear filtering so text stays smooth at any scale. Uploads are batched per frame.
 */
final class GlyphAtlas implements AutoCloseable {
	static final int SIZE = 1024;
	private static final int PADDING = 2;

	private final String label;
	private final NativeImage image;
	private final DynamicTexture texture;
	private TextureSetup textureSetup;
	private Identifier worldId;
	private RenderType worldType;
	private RenderType worldTypeSeeThrough;
	private int cursorX = PADDING;
	private int cursorY = PADDING;
	private int rowHeight;
	private boolean dirty;

	GlyphAtlas(String label) {
		this.label = label;
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

	/**
	 * Render type drawing this page in the world. The page is registered with the texture manager on first use
	 * (world render types reference textures by id); the GUI path does not need that.
	 */
	RenderType worldType(boolean seeThrough) {
		if (worldId == null) {
			worldId = Identifier.parse(label);
			Minecraft.getInstance().getTextureManager().register(worldId, texture);
			worldType = create("_world", ShadowPipelines.WORLD_SDF_TEXT);
			worldTypeSeeThrough = create("_world_see_through", ShadowPipelines.WORLD_SDF_TEXT_SEE_THROUGH);
		}
		return seeThrough ? worldTypeSeeThrough : worldType;
	}

	private RenderType create(String suffix, com.mojang.blaze3d.pipeline.RenderPipeline pipeline) {
		return RenderType.create(label + suffix, RenderSetup.builder(pipeline)
			.withTexture("Sampler0", worldId, () -> RenderSystem.getSamplerCache().getClampToEdge(FilterMode.LINEAR))
			.sortOnUpload()
			.createRenderSetup());
	}

	@Override
	public void close() {
		if (worldId != null) {
			// The texture manager owns the texture once registered and closes it on release.
			Minecraft.getInstance().getTextureManager().release(worldId);
			worldId = null;
		} else {
			texture.close();
		}
	}
}
