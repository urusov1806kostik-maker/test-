package dev.nyxveravisuals.ui.overlay;

import java.util.ArrayList;
import java.util.List;

import dev.nyxveravisuals.ui.UiContext;

/**
 * Z-ordered stack of overlays. The topmost open overlay gets input first; clicks outside a non-modal
 * overlay close it and are consumed, so they never reach the widget underneath.
 */
public final class OverlayManager {
	private static final float BLOCKED = -1e6f;
	private final List<Overlay> stack = new ArrayList<>();

	public void open(Overlay overlay) {
		stack.add(overlay);
	}

	public void closeAll() {
		for (Overlay overlay : stack) {
			overlay.close();
		}
	}

	public boolean hasOpen() {
		for (Overlay overlay : stack) {
			if (!overlay.isClosing()) {
				return true;
			}
		}
		return false;
	}

	/** True if the point is covered by an open overlay or a modal overlay is open. */
	public boolean captures(float x, float y) {
		for (Overlay overlay : stack) {
			if (!overlay.isClosing() && (overlay.isModal() || overlay.contains(x, y))) {
				return true;
			}
		}
		return false;
	}

	public void render(UiContext context, float mouseX, float mouseY) {
		stack.removeIf(Overlay::isFinished);
		Overlay top = top();
		int count = stack.size();
		for (int i = 0; i < count; i++) {
			Overlay overlay = stack.get(i);
			overlay.layout(context);
			boolean interactive = overlay == top;
			overlay.render(context, interactive ? mouseX : BLOCKED, interactive ? mouseY : BLOCKED);
		}
	}

	private Overlay top() {
		for (int i = stack.size() - 1; i >= 0; i--) {
			if (!stack.get(i).isClosing()) {
				return stack.get(i);
			}
		}
		return null;
	}

	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		for (int i = stack.size() - 1; i >= 0; i--) {
			Overlay overlay = stack.get(i);
			if (overlay.isClosing()) {
				continue;
			}
			if (overlay.contains(mouseX, mouseY)) {
				overlay.mouseClicked(context, mouseX, mouseY, button);
				return true;
			}
			if (overlay.isModal()) {
				return true;
			}
			overlay.close();
			return true;
		}
		return false;
	}

	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		Overlay top = top();
		if (top != null) {
			top.mouseReleased(context, mouseX, mouseY, button);
			return true;
		}
		return false;
	}

	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		Overlay top = top();
		if (top == null) {
			return false;
		}
		top.mouseDragged(context, mouseX, mouseY, button);
		return true;
	}

	public boolean mouseScrolled(UiContext context, float mouseX, float mouseY, double amount) {
		Overlay top = top();
		if (top == null) {
			return false;
		}
		if (top.contains(mouseX, mouseY)) {
			top.mouseScrolled(context, mouseX, mouseY, amount);
		}
		return true;
	}

	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		Overlay top = top();
		return top != null && top.keyPressed(context, key, scancode, modifiers);
	}

	public boolean charTyped(UiContext context, int codePoint) {
		Overlay top = top();
		return top != null && top.charTyped(context, codePoint);
	}
}
