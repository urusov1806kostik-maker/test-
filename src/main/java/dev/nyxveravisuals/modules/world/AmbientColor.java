package dev.nyxveravisuals.modules.world;

import org.joml.Vector3f;
import org.joml.Vector3fc;

import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.NumberSetting;

/** Tints the ambient (block and sky) light balance of the lightmap. */
public final class AmbientColor extends Module {
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFF9FB4FF, false));
	private final NumberSetting intensity = settings().add(new NumberSetting("intensity", 0.4, 0.05, 1.0, 0.05));
	private final Vector3f result = new Vector3f();

	public AmbientColor() {
		super("ambient_color", Category.WORLD);
	}

	public Vector3fc tint(Vector3fc vanilla) {
		return WorldColor.blend(vanilla, color.color(), intensity.getFloat(), result);
	}
}
