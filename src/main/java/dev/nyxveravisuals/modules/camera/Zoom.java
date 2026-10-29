package dev.nyxveravisuals.modules.camera;

import org.lwjgl.glfw.GLFW;

import dev.nyxveravisuals.animation.SmoothValue;
import dev.nyxveravisuals.event.events.MouseScrollEvent;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.Keybind;
import dev.nyxveravisuals.setting.NumberSetting;

/**
 * Smooth optical zoom. Hold the bind (default C) to zoom; the wheel adjusts the zoom level while zooming
 * and mouse sensitivity scales with the zoom so aiming stays consistent.
 */
public final class Zoom extends Module {
	private final NumberSetting factor = settings().add(new NumberSetting("zoom_factor", 4.0, 1.5, 15.0, 0.5).suffix("x"));
	private final BooleanSetting scroll = settings().add(new BooleanSetting("scroll_adjust", true));
	private final BooleanSetting smooth = settings().add(new BooleanSetting("smooth", true));
	private final BooleanSetting scaleSensitivity = settings().add(new BooleanSetting("scale_sensitivity", true));
	private final SmoothValue current = new SmoothValue(1f, 12f);
	private float scrolled = 1f;

	public Zoom() {
		super("zoom", Category.CAMERA);
		bind().set(Keybind.key(GLFW.GLFW_KEY_C));
		bindMode().set(BindMode.HOLD);
		on(MouseScrollEvent.class, event -> {
			if (scroll.get() && event.vertical() != 0) {
				scrolled = Math.max(0.25f, Math.min(4f, scrolled * (event.vertical() > 0 ? 1.15f : 1f / 1.15f)));
				event.cancel();
			}
		});
	}

	@Override
	protected void onEnable() {
		scrolled = 1f;
	}

	/** Current zoom multiplier (1 = none); keeps animating out after release. */
	public float amount() {
		float target = isEnabled() ? Math.max(1f, factor.getFloat() * scrolled) : 1f;
		if (!smooth.get()) {
			current.snap(target);
		} else {
			current.setTarget(target);
		}
		return current.get();
	}

	public boolean scalesSensitivity() {
		return scaleSensitivity.get();
	}
}
