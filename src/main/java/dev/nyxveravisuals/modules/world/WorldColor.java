package dev.nyxveravisuals.modules.world;

import org.joml.Vector3f;
import org.joml.Vector3fc;

import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.util.ColorUtil;

/** Tints the sky light of the world (lightmap sky color) client-side. */
public final class WorldColor extends Module {
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFFB9A8FF, false));
	private final NumberSetting intensity = settings().add(new NumberSetting("intensity", 0.5, 0.05, 1.0, 0.05));
	private final Vector3f result = new Vector3f();

	public WorldColor() {
		super("world_color", Category.WORLD);
	}

	public Vector3fc tint(Vector3fc vanilla) {
		return blend(vanilla, color.color(), intensity.getFloat(), result);
	}

	static Vector3fc blend(Vector3fc vanilla, int argb, float amount, Vector3f out) {
		float r = ColorUtil.red(argb) / 255f;
		float g = ColorUtil.green(argb) / 255f;
		float b = ColorUtil.blue(argb) / 255f;
		return out.set(vanilla.x() + (vanilla.x() * r - vanilla.x()) * amount,
			vanilla.y() + (vanilla.y() * g - vanilla.y()) * amount,
			vanilla.z() + (vanilla.z() * b - vanilla.z()) * amount);
	}
}
