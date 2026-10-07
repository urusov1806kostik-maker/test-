package dev.shadowvisuals.modules.camera;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.NumberSetting;

/** Scales (or removes) the camera tilt when you take damage. */
public final class HurtCamera extends Module {
	private final NumberSetting strength = settings().add(new NumberSetting("strength", 0.3, 0.0, 1.0, 0.05).suffix("x"));

	public HurtCamera() {
		super("hurt_camera", Category.CAMERA);
	}

	public float strength() {
		return strength.getFloat();
	}
}
