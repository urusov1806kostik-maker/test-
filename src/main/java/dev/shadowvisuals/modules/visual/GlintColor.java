package dev.shadowvisuals.modules.visual;

import java.io.IOException;
import java.io.InputStream;
import java.util.Optional;

import com.mojang.blaze3d.platform.NativeImage;
import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.textures.FilterMode;

import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.RenderPipelines;
import net.minecraft.client.renderer.entity.ItemRenderer;
import net.minecraft.client.renderer.rendertype.LayeringTransform;
import net.minecraft.client.renderer.rendertype.OutputTarget;
import net.minecraft.client.renderer.rendertype.RenderSetup;
import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.rendertype.TextureTransform;
import net.minecraft.client.renderer.texture.DynamicTexture;
import net.minecraft.resources.Identifier;
import net.minecraft.server.packs.resources.Resource;

import dev.shadowvisuals.core.ClientInfo;
import dev.shadowvisuals.core.Log;
import dev.shadowvisuals.event.events.ClientTickEvent;
import dev.shadowvisuals.event.events.ResourceReloadEvent;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Recolors the enchantment glint. The current resource pack's glint textures are tinted into two dynamic
 * textures, and the vanilla glint render types are swapped (via mixin) for copies that sample them, so
 * animation speed and strength options keep working. Rainbow colors re-tint at most ten times a second.
 */
public final class GlintColor extends Module {
	private static final Identifier ITEM_ID = Identifier.fromNamespaceAndPath(ClientInfo.MOD_ID, "dynamic/glint_item");
	private static final Identifier ARMOR_ID = Identifier.fromNamespaceAndPath(ClientInfo.MOD_ID, "dynamic/glint_armor");

	private static RenderType glint;
	private static RenderType glintTranslucent;
	private static RenderType entityGlint;
	private static RenderType armorEntityGlint;

	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFF8B7CF6, false));
	private final NumberSetting intensity = settings().add(new NumberSetting("intensity", 1.0, 0.2, 2.0, 0.05).suffix("x"));

	private NativeImage itemSource;
	private NativeImage armorSource;
	private DynamicTexture itemTexture;
	private DynamicTexture armorTexture;
	private int appliedColor;
	private float appliedIntensity = -1;
	private int tickCounter;
	private boolean ready;

	public GlintColor() {
		super("glint_color", Category.VISUAL);
		color.onChange(value -> retint(true));
		intensity.onChange(value -> retint(true));
		on(ResourceReloadEvent.class, event -> {
			release();
			load();
		});
		on(ClientTickEvent.class, event -> {
			if (!event.isPre() && color.isRainbow() && ++tickCounter % 2 == 0) {
				retint(false);
			}
		});
	}

	@Override
	protected void onEnable() {
		load();
	}

	@Override
	protected void onDisable() {
		release();
	}

	private static RenderType create(String name, Identifier texture, TextureTransform transform, boolean armor, boolean translucent) {
		RenderSetup.RenderSetupBuilder builder = RenderSetup.builder(RenderPipelines.GLINT)
			.withTexture("Sampler0", texture, () -> RenderSystem.getSamplerCache().getRepeat(FilterMode.LINEAR))
			.setTextureTransform(transform);
		if (armor) {
			builder.setLayeringTransform(LayeringTransform.VIEW_OFFSET_Z_LAYERING);
		}
		if (translucent) {
			builder.setOutputTarget(OutputTarget.ITEM_ENTITY_TARGET);
		}
		return RenderType.create(ClientInfo.MOD_ID + "_" + name, builder.createRenderSetup());
	}

	private static void ensureRenderTypes() {
		if (glint == null) {
			glint = create("glint", ITEM_ID, TextureTransform.GLINT_TEXTURING, false, false);
			glintTranslucent = create("glint_translucent", ITEM_ID, TextureTransform.GLINT_TEXTURING, false, true);
			entityGlint = create("entity_glint", ITEM_ID, TextureTransform.ENTITY_GLINT_TEXTURING, false, false);
			armorEntityGlint = create("armor_entity_glint", ARMOR_ID, TextureTransform.ARMOR_ENTITY_GLINT_TEXTURING, true, false);
		}
	}

	private void load() {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft == null || minecraft.getResourceManager() == null) {
			return;
		}
		itemSource = read(minecraft, ItemRenderer.ENCHANTED_GLINT_ITEM);
		armorSource = read(minecraft, ItemRenderer.ENCHANTED_GLINT_ARMOR);
		if (itemSource == null || armorSource == null) {
			release();
			return;
		}
		itemTexture = new DynamicTexture(() -> ITEM_ID.toString(), new NativeImage(itemSource.getWidth(), itemSource.getHeight(), false));
		armorTexture = new DynamicTexture(() -> ARMOR_ID.toString(), new NativeImage(armorSource.getWidth(), armorSource.getHeight(), false));
		minecraft.getTextureManager().register(ITEM_ID, itemTexture);
		minecraft.getTextureManager().register(ARMOR_ID, armorTexture);
		ensureRenderTypes();
		retint(true);
		ready = true;
	}

	private static NativeImage read(Minecraft minecraft, Identifier id) {
		Optional<Resource> resource = minecraft.getResourceManager().getResource(id);
		if (resource.isEmpty()) {
			Log.warnOnce("glint-missing-" + id, "Glint texture {} not found", id);
			return null;
		}
		try (InputStream stream = resource.get().open()) {
			return NativeImage.read(stream);
		} catch (IOException e) {
			Log.warnOnce("glint-read-" + id, "Could not read glint texture {}", id, e);
			return null;
		}
	}

	private void retint(boolean force) {
		if (itemTexture == null || armorTexture == null) {
			return;
		}
		int target = color.color();
		float strength = intensity.getFloat();
		if (!force && target == appliedColor && strength == appliedIntensity) {
			return;
		}
		appliedColor = target;
		appliedIntensity = strength;
		tint(itemSource, itemTexture, target, strength);
		tint(armorSource, armorTexture, target, strength);
	}

	/** Keeps the glint's brightness pattern but replaces its hue with {@code color}. */
	private static void tint(NativeImage source, DynamicTexture texture, int color, float strength) {
		NativeImage pixels = texture.getPixels();
		if (pixels == null) {
			return;
		}
		float red = ColorUtil.red(color) / 255f;
		float green = ColorUtil.green(color) / 255f;
		float blue = ColorUtil.blue(color) / 255f;
		for (int y = 0; y < source.getHeight(); y++) {
			for (int x = 0; x < source.getWidth(); x++) {
				int pixel = source.getPixel(x, y);
				float level = Math.max(ColorUtil.red(pixel), Math.max(ColorUtil.green(pixel), ColorUtil.blue(pixel))) / 255f * strength;
				pixels.setPixel(x, y, ColorUtil.argb(ColorUtil.alpha(pixel),
					Math.min(255, Math.round(red * level * 255)),
					Math.min(255, Math.round(green * level * 255)),
					Math.min(255, Math.round(blue * level * 255))));
			}
		}
		texture.upload();
	}

	private void release() {
		ready = false;
		Minecraft minecraft = Minecraft.getInstance();
		if (itemTexture != null && minecraft != null) {
			minecraft.getTextureManager().release(ITEM_ID);
			minecraft.getTextureManager().release(ARMOR_ID);
		}
		itemTexture = null;
		armorTexture = null;
		if (itemSource != null) {
			itemSource.close();
			itemSource = null;
		}
		if (armorSource != null) {
			armorSource.close();
			armorSource = null;
		}
	}

	/** Used by the render-type mixin; {@code null} keeps the vanilla glint. */
	public RenderType replacement(int kind) {
		if (!ready) {
			return null;
		}
		return switch (kind) {
			case 0 -> glint;
			case 1 -> glintTranslucent;
			case 2 -> entityGlint;
			default -> armorEntityGlint;
		};
	}
}
