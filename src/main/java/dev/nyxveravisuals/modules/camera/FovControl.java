package dev.nyxveravisuals.modules.camera;

import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.NumberSetting;

/** FOV offset and an option to ignore speed/effect FOV changes. */
public final class FovControl extends Module {
	private final NumberSetting offset = settings().add(new NumberSetting("fov_offset", 0, -30, 30, 1).suffix("°"));
	private final BooleanSetting staticFov = settings().add(new BooleanSetting("static_fov", true));

	public FovControl() {
		super("fov_control", Category.CAMERA);
	}

	public float apply(float vanilla, float base) {
		return (staticFov.get() ? base : vanilla) + offset.getFloat();
	}
}
