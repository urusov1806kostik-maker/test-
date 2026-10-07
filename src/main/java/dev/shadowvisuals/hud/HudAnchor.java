package dev.shadowvisuals.hud;

/**
 * Screen point a HUD element is attached to. The element keeps its offset from this point, so it stays glued
 * to the same edge or corner when the window or GUI scale changes.
 */
public enum HudAnchor {
	TOP_LEFT(0f, 0f),
	TOP_CENTER(0.5f, 0f),
	TOP_RIGHT(1f, 0f),
	MIDDLE_LEFT(0f, 0.5f),
	CENTER(0.5f, 0.5f),
	MIDDLE_RIGHT(1f, 0.5f),
	BOTTOM_LEFT(0f, 1f),
	BOTTOM_CENTER(0.5f, 1f),
	BOTTOM_RIGHT(1f, 1f);

	private final float fx;
	private final float fy;

	HudAnchor(float fx, float fy) {
		this.fx = fx;
		this.fy = fy;
	}

	/** Horizontal factor: 0 = left, 0.5 = center, 1 = right (used for both screen point and element pivot). */
	public float fx() {
		return fx;
	}

	public float fy() {
		return fy;
	}

	public boolean alignsRight() {
		return fx == 1f;
	}

	/** Picks the anchor whose region (thirds of the screen) contains the element's center. */
	public static HudAnchor nearest(float centerX, float centerY, float screenWidth, float screenHeight) {
		int column = centerX < screenWidth / 3f ? 0 : centerX > screenWidth * 2f / 3f ? 2 : 1;
		int row = centerY < screenHeight / 3f ? 0 : centerY > screenHeight * 2f / 3f ? 2 : 1;
		return values()[row * 3 + column];
	}
}
