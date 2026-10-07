package dev.shadowvisuals.modules.player;

import com.mojang.blaze3d.platform.NativeImage;

import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.texture.DynamicTexture;

import dev.shadowvisuals.event.events.ResourceReloadEvent;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.ColorSetting;

/**
 * Recolors the damage flash of entities by rewriting the vanilla overlay texture's hurt rows. The original
 * color is restored on disable.
 */
public final class HitColor extends Module {
	private static final int VANILLA = 0xB3FF0000;

	private final ColorSetting color = settings().add(new ColorSetting("color", 0xB38B7CF6, true));

	public HitColor() {
		super("hit_color", Category.PLAYER);
		color.onChange(value -> {
			if (isEnabled()) {
				apply(color.color());
			}
		});
		on(ResourceReloadEvent.class, event -> apply(color.color()));
	}

	@Override
	protected void onEnable() {
		apply(color.color());
	}

	@Override
	protected void onDisable() {
		apply(VANILLA);
	}

	private static void apply(int argb) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft == null || minecraft.gameRenderer == null) {
			return;
		}
		DynamicTexture texture = minecraft.gameRenderer.overlayTexture().texture;
		NativeImage pixels = texture.getPixels();
		if (pixels == null) {
			return;
		}
		for (int y = 0; y < 8; y++) {
			for (int x = 0; x < 16; x++) {
				pixels.setPixel(x, y, argb);
			}
		}
		texture.upload();
	}
}
