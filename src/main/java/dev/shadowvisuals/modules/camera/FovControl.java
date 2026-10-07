package dev.shadowvisuals.modules.camera;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.NumberSetting;

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
