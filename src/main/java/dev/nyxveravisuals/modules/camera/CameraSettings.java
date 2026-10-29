package dev.nyxveravisuals.modules.camera;

import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.NumberSetting;

/** Third-person camera distance. */
public final class CameraSettings extends Module {
	private final NumberSetting distance = settings().add(new NumberSetting("third_person_distance", 4.0, 1.0, 12.0, 0.25));

	public CameraSettings() {
		super("camera_settings", Category.CAMERA);
	}

	public float distance(float vanilla) {
		return vanilla / 4f * distance.getFloat();
	}
}
