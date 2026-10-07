package dev.shadowvisuals.modules.camera;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.NumberSetting;

/** Scales the walking camera bob (the vanilla "View Bobbing" option must stay on for any bob). */
public final class ViewBobbing extends Module {
	private final NumberSetting strength = settings().add(new NumberSetting("strength", 0.5, 0.0, 1.0, 0.05).suffix("x"));

	public ViewBobbing() {
		super("view_bobbing", Category.CAMERA);
	}

	public float strength() {
		return strength.getFloat();
	}
}
