package dev.nyxveravisuals.render.font;

import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Map;

import net.minecraft.client.Minecraft;

import dev.nyxveravisuals.core.Log;
import dev.nyxveravisuals.render.NyxveraPipelines;

/**
 * Loads the client fonts once and caches text layouts. If a font cannot be loaded, or the text shader is
 * unavailable, every call transparently falls back to the vanilla Minecraft font.
 */
public final class FontManager implements AutoCloseable {
	public enum Weight {
		MEDIUM("/assets/nyxveravisuals/font/inter_medium.ttf"),
		SEMIBOLD("/assets/nyxveravisuals/font/inter_semibold.ttf");

		private final String resource;

		Weight(String resource) {
			this.resource = resource;
		}
	}

	private static final int CACHE_SIZE = 2048;
	/** Vanilla glyphs are 7 units tall for capitals; used to size the fallback font to match. */
	private static final float VANILLA_CAP_HEIGHT = 7f;
	private static final float DEFAULT_CAP_HEIGHT = 0.727f;

	private final Map<Weight, SdfFont> fonts = new EnumMap<>(Weight.class);
	private final Map<Weight, Map<String, TextLayout>> layouts = new EnumMap<>(Weight.class);
	private boolean loaded;
	private boolean useCustomFont = true;

	/** Loads the fonts on the render thread. Safe to call again after {@link #close()}. */
	public void init() {
		close();
		try {
			for (Weight weight : Weight.values()) {
				fonts.put(weight, SdfFont.load(weight.name().toLowerCase(java.util.Locale.ROOT), weight.resource));
				layouts.put(weight, lruCache());
			}
			loaded = true;
		} catch (Exception | LinkageError e) {
			Log.error("Could not load client fonts; falling back to the Minecraft font", e);
			close();
		}
	}

	private static Map<String, TextLayout> lruCache() {
		return new LinkedHashMap<>(256, 0.75f, true) {
			@Override
			protected boolean removeEldestEntry(Map.Entry<String, TextLayout> eldest) {
				return size() > CACHE_SIZE;
			}
		};
	}

	/** User preference: the custom font can be turned off in client settings. */
	public void setUseCustomFont(boolean value) {
		this.useCustomFont = value;
	}

	public boolean usingCustomFont() {
		return loaded && useCustomFont && NyxveraPipelines.textAvailable();
	}

	SdfFont font(Weight weight) {
		return fonts.get(weight);
	}

	/** Cached layout, or {@code null} when the custom font is not in use. */
	public TextLayout layout(String text, Weight weight) {
		if (!usingCustomFont()) {
			return null;
		}
		Map<String, TextLayout> cache = layouts.get(weight);
		TextLayout layout = cache.get(text);
		if (layout == null) {
			layout = TextLayout.build(fonts.get(weight), text);
			cache.put(text, layout);
			// New glyphs may have been rasterized: upload now so this frame already draws them.
			fonts.get(weight).uploadPending();
		}
		return layout;
	}

	public float width(String text, float size, Weight weight) {
		TextLayout layout = layout(text, weight);
		if (layout != null && layout.complete()) {
			return layout.width() * size;
		}
		return Minecraft.getInstance().font.width(text) * vanillaScale(size);
	}

	/** Scale applied to the vanilla font so its capitals match the custom font at {@code size}. */
	public float vanillaScale(float size) {
		return size * capHeightEm() / VANILLA_CAP_HEIGHT;
	}

	public float capHeightEm() {
		SdfFont font = fonts.get(Weight.MEDIUM);
		return usingCustomFont() && font != null ? font.capHeight() : DEFAULT_CAP_HEIGHT;
	}

	public float ascenderEm() {
		SdfFont font = fonts.get(Weight.MEDIUM);
		return usingCustomFont() && font != null ? font.ascender() : 0.95f;
	}

	public float lineHeight(float size) {
		SdfFont font = fonts.get(Weight.MEDIUM);
		return usingCustomFont() && font != null ? font.lineHeight() * size : size * 1.2f;
	}

	/** Distance from the top of the text box to the visual middle of capital letters. */
	public float visualCenter(float size) {
		return (ascenderEm() - capHeightEm() * 0.5f) * size;
	}

	public void uploadPending() {
		for (SdfFont font : fonts.values()) {
			font.uploadPending();
		}
	}

	@Override
	public void close() {
		for (SdfFont font : fonts.values()) {
			try {
				font.close();
			} catch (RuntimeException e) {
				Log.warn("Failed to release font resources", e);
			}
		}
		fonts.clear();
		layouts.clear();
		loaded = false;
	}
}
