package dev.nyxveravisuals.ui.overlay;

import dev.nyxveravisuals.animation.Animation;
import dev.nyxveravisuals.animation.Easing;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Component;

/**
 * Floating layer above the main tree (dropdown, color picker, context menu, dialog). Overlays receive input
 * before anything else; a modal overlay also blocks every click outside of it.
 */
public abstract class Overlay extends Component {
	private final Animation presence = new Animation(0f, 0.14f, Easing.EASE_OUT_CUBIC);
	private final boolean modal;
	private boolean closing;
	private Runnable onClose;

	protected Overlay(boolean modal) {
		this.modal = modal;
		presence.animateTo(1f);
	}

	public boolean isModal() {
		return modal;
	}

	public Overlay onClose(Runnable callback) {
		this.onClose = callback;
		return this;
	}

	public final void close() {
		if (!closing) {
			closing = true;
			presence.animateTo(0f);
			if (onClose != null) {
				onClose.run();
			}
		}
	}

	public final boolean isClosing() {
		return closing;
	}

	final boolean isFinished() {
		return closing && presence.isFinishedAtZero();
	}

	/** Appearance progress {@code 0..1}. */
	protected final float presence() {
		return presence.value();
	}

	/** Lays out the overlay for the current viewport (keeps it on screen). Called every frame. */
	protected abstract void layout(UiContext context);

	/** Escape closes overlays by default. */
	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		if (key == org.lwjgl.glfw.GLFW.GLFW_KEY_ESCAPE) {
			close();
			return true;
		}
		return false;
	}
}
