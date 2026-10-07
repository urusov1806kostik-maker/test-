package dev.shadowvisuals.modules.visual;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;

/**
 * Brightens the world through the lightmap uniforms instead of changing the gamma option, so there is
 * nothing to restore: disabling the module returns vanilla lighting on the next lightmap update.
 */
public final class FullBright extends Module {
	public enum Mode {
		NIGHT_VISION,
		GAMMA
	}

	private final ModeSetting<Mode> mode = settings().add(new ModeSetting<>("mode", Mode.NIGHT_VISION));
	private final NumberSetting strength = settings().add(new NumberSetting("strength", 10, 1, 15, 0.5))
		.visibleWhen(() -> mode.get() == Mode.GAMMA);

	public FullBright() {
		super("fullbright", Category.VISUAL);
	}

	public float nightVision(float vanilla) {
		return mode.get() == Mode.NIGHT_VISION ? 1f : vanilla;
	}

	public float brightness(float vanilla) {
		return mode.get() == Mode.GAMMA ? Math.max(vanilla, strength.getFloat()) : vanilla;
	}

	@Override
	public String listSuffix() {
		return mode.get() == Mode.GAMMA ? "Gamma" : "NV";
	}
}
