package dev.shadowvisuals.modules.world;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.util.ColorUtil;

/** Recolors the sky dome (client-side render state only). */
public final class SkyColor extends Module {
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFF7B6CF0, false));
	private final NumberSetting intensity = settings().add(new NumberSetting("intensity", 0.7, 0.05, 1.0, 0.05));

	public SkyColor() {
		super("sky_color", Category.WORLD);
	}

	public int apply(int vanilla) {
		return ColorUtil.lerp(vanilla | 0xFF000000, color.color(), intensity.getFloat()) & 0xFFFFFF | (vanilla & 0xFF000000);
	}
}
