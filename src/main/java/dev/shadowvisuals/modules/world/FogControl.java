package dev.shadowvisuals.modules.world;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.setting.NumberSetting;

/**
 * Adjusts atmospheric fog distance per dimension. Water, lava, powder snow, blindness and darkness fog are
 * never touched, so special visual states keep working.
 */
public final class FogControl extends Module {
	private final NumberSetting overworld = settings().add(new NumberSetting("overworld_distance", 2.0, 0.25, 4.0, 0.05).suffix("x"));
	private final NumberSetting nether = settings().add(new NumberSetting("nether_distance", 1.5, 0.25, 4.0, 0.05).suffix("x"));
	private final NumberSetting end = settings().add(new NumberSetting("end_distance", 1.5, 0.25, 4.0, 0.05).suffix("x"));
	private final BooleanSetting customColor = settings().add(new BooleanSetting("custom_color", false));
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFF4A3F8C, false)).dependsOn(customColor);

	public FogControl() {
		super("fog_control", Category.WORLD);
	}

	public float multiplier(String dimension) {
		return switch (dimension) {
			case "minecraft:the_nether" -> nether.getFloat();
			case "minecraft:the_end" -> end.getFloat();
			default -> overworld.getFloat();
		};
	}

	public boolean customColor() {
		return customColor.get();
	}

	public int color() {
		return color.color();
	}
}
