package dev.nyxveravisuals.hud;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import dev.nyxveravisuals.core.Log;

/**
 * Renders every enabled HUD element each frame (with fade/scale presence animation) and offers the queries
 * the HUD editor needs. Elements render independently: one failing element is skipped, not the HUD.
 */
public final class HudManager {
	private final List<HudModule> elements = new ArrayList<>();
	private final List<HudModule> view = Collections.unmodifiableList(elements);

	public void register(HudModule module) {
		elements.add(module);
	}

	public List<HudModule> elements() {
		return view;
	}

	public void render(HudContext context) {
		for (HudModule element : elements) {
			try {
				element.render(context, context.screenWidth(), context.screenHeight());
			} catch (Exception | LinkageError e) {
				Log.errorOnce("hud:" + element.id(), "HUD element '{}' failed to render; disabling it", element.id(), e);
				element.setEnabled(false);
			}
		}
	}

	/** Topmost enabled element under the point, or {@code null}. */
	public HudModule elementAt(float x, float y) {
		for (int i = elements.size() - 1; i >= 0; i--) {
			HudModule element = elements.get(i);
			if (element.isEnabled() && element.contains(x, y)) {
				return element;
			}
		}
		return null;
	}

	public void resetPositions() {
		for (HudModule element : elements) {
			element.resetPosition();
		}
	}
}
