package dev.shadowvisuals.ui.component;

import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.ui.UiContext;

/**
 * Base of every Shadow Visuals widget. Bounds are absolute logical coordinates assigned by the parent's
 * layout each frame; hover state and its animation are handled here so widgets never re-implement it.
 * Input methods return {@code true} when the event was consumed.
 */
public abstract class Component {
	protected float x;
	protected float y;
	protected float width;
	protected float height;
	protected boolean visible = true;
	private boolean hovered;
	private final Animation hoverAnimation = new Animation(0f, DesignTokens.DURATION_HOVER, Easing.EASE_OUT_QUAD);

	public final Component setBounds(float newX, float newY, float newWidth, float newHeight) {
		this.x = newX;
		this.y = newY;
		this.width = newWidth;
		this.height = newHeight;
		return this;
	}

	public float x() {
		return x;
	}

	public float y() {
		return y;
	}

	public float width() {
		return width;
	}

	public float height() {
		return height;
	}

	public boolean isVisible() {
		return visible;
	}

	public void setVisible(boolean value) {
		this.visible = value;
	}

	public boolean contains(float pointX, float pointY) {
		return pointX >= x && pointY >= y && pointX < x + width && pointY < y + height;
	}

	public final boolean isHovered() {
		return hovered;
	}

	/** Hover progress {@code 0..1}, animated. */
	public final float hover() {
		return hoverAnimation.value();
	}

	/** Renders this component; mouse coordinates are already blocked (off-screen) when an overlay covers them. */
	public final void render(UiContext context, float mouseX, float mouseY) {
		if (!visible) {
			return;
		}
		hovered = contains(mouseX, mouseY);
		hoverAnimation.animateTo(hovered ? 1f : 0f);
		draw(context, mouseX, mouseY);
		if (hovered) {
			String tooltip = tooltip(context);
			if (tooltip != null) {
				context.tooltips().offer(this, tooltip, x, y, width, height);
			}
		}
	}

	protected abstract void draw(UiContext context, float mouseX, float mouseY);

	/** Preferred height for a given width; used by vertical layouts. */
	public float preferredHeight(UiContext context, float availableWidth) {
		return height;
	}

	/** Tooltip text shown after a short delay while hovered, or {@code null}. */
	protected String tooltip(UiContext context) {
		return null;
	}

	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		return false;
	}

	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		return false;
	}

	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		return false;
	}

	public boolean mouseScrolled(UiContext context, float mouseX, float mouseY, double amount) {
		return false;
	}

	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		return false;
	}

	public boolean charTyped(UiContext context, int codePoint) {
		return false;
	}

	/** Called when this component loses keyboard focus. */
	public void onFocusLost(UiContext context) {
	}
}
