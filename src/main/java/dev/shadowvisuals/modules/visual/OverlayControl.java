package dev.shadowvisuals.modules.visual;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.BooleanSetting;

/** Turns off distracting screen overlays individually. */
public final class OverlayControl extends Module {
	private final BooleanSetting vignette = settings().add(new BooleanSetting("hide_vignette", true));
	private final BooleanSetting pumpkin = settings().add(new BooleanSetting("hide_pumpkin", true));
	private final BooleanSetting powderSnow = settings().add(new BooleanSetting("hide_powder_snow", false));
	private final BooleanSetting portal = settings().add(new BooleanSetting("hide_portal", true));
	private final BooleanSetting nausea = settings().add(new BooleanSetting("hide_nausea", true));
	private final BooleanSetting blockInside = settings().add(new BooleanSetting("hide_block_overlay", true));
	private final BooleanSetting water = settings().add(new BooleanSetting("hide_water_overlay", false));

	public OverlayControl() {
		super("overlay_control", Category.VISUAL);
	}

	public boolean vignette() {
		return vignette.get();
	}

	public boolean pumpkin() {
		return pumpkin.get();
	}

	public boolean powderSnow() {
		return powderSnow.get();
	}

	public boolean portal() {
		return portal.get();
	}

	public boolean nausea() {
		return nausea.get();
	}

	public boolean blockInside() {
		return blockInside.get();
	}

	public boolean water() {
		return water.get();
	}
}
