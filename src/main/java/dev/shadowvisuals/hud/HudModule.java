package dev.shadowvisuals.hud;

import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.util.MathUtil;

/**
 * A module that owns one movable HUD element. Position is stored as an anchor plus offset (persisted with
 * the module), the element reports its own size while rendering, and appearance/disappearance is animated
 * instead of popping.
 */
public abstract class HudModule extends Module {
	private final HudAnchor defaultAnchor;
	private final float defaultOffsetX;
	private final float defaultOffsetY;

	private final ModeSetting<HudAnchor> anchor;
	private final NumberSetting offsetX;
	private final NumberSetting offsetY;
	protected final NumberSetting scale;

	private final Animation presence = new Animation(0f, DesignTokens.DURATION_PANEL, Easing.EASE_OUT_CUBIC);
	private float width = 60;
	private float height = 14;
	private float lastX;
	private float lastY;

	protected HudModule(String id, Category category, boolean enabledByDefault, HudAnchor anchor, float offsetX, float offsetY) {
		super(id, category, enabledByDefault);
		this.defaultAnchor = anchor;
		this.defaultOffsetX = offsetX;
		this.defaultOffsetY = offsetY;
		this.scale = settings().add(new NumberSetting("scale", 1.0, 0.5, 2.0, 0.05).suffix("x"));
		this.anchor = settings().add(new ModeSetting<>("hud_anchor", anchor)).internal();
		this.offsetX = settings().add(new NumberSetting("hud_x", offsetX, -4096, 4096, 0.5)).internal();
		this.offsetY = settings().add(new NumberSetting("hud_y", offsetY, -4096, 4096, 0.5)).internal();
	}

	/** Draws the element with its top-left at the local origin and reports its size via {@link #setSize}. */
	protected abstract void renderContent(HudContext context);

	/** False hides the element (animated), e.g. no potion effects active. Editing always shows it. */
	protected boolean hasContent(HudContext context) {
		return true;
	}

	protected final void setSize(float contentWidth, float contentHeight) {
		this.width = Math.max(4, contentWidth);
		this.height = Math.max(4, contentHeight);
	}

	public float width() {
		return width;
	}

	public float height() {
		return height;
	}

	public float scaledWidth() {
		return width * scale.getFloat();
	}

	public float scaledHeight() {
		return height * scale.getFloat();
	}

	public float scale() {
		return scale.getFloat();
	}

	public HudAnchor anchor() {
		return anchor.get();
	}

	/** Top-left screen position for the current size, clamped so the element never leaves the screen. */
	public float x(float screenWidth) {
		HudAnchor current = anchor.get();
		float raw = current.fx() * screenWidth + offsetX.getFloat() - current.fx() * scaledWidth();
		return MathUtil.clamp(raw, 0, Math.max(0, screenWidth - scaledWidth()));
	}

	public float y(float screenHeight) {
		HudAnchor current = anchor.get();
		float raw = current.fy() * screenHeight + offsetY.getFloat() - current.fy() * scaledHeight();
		return MathUtil.clamp(raw, 0, Math.max(0, screenHeight - scaledHeight()));
	}

	/** Moves the element so its top-left lands at {@code (x, y)}, re-anchoring to the nearest screen region. */
	public void moveTo(float x, float y, float screenWidth, float screenHeight) {
		float clampedX = MathUtil.clamp(x, 0, Math.max(0, screenWidth - scaledWidth()));
		float clampedY = MathUtil.clamp(y, 0, Math.max(0, screenHeight - scaledHeight()));
		HudAnchor nearest = HudAnchor.nearest(clampedX + scaledWidth() / 2f, clampedY + scaledHeight() / 2f, screenWidth, screenHeight);
		anchor.set(nearest);
		offsetX.set((double) (clampedX - nearest.fx() * screenWidth + nearest.fx() * scaledWidth()));
		offsetY.set((double) (clampedY - nearest.fy() * screenHeight + nearest.fy() * scaledHeight()));
	}

	public void resetPosition() {
		anchor.set(defaultAnchor);
		offsetX.set((double) defaultOffsetX);
		offsetY.set((double) defaultOffsetY);
		scale.reset();
	}

	/** Called by the HUD manager each frame; handles visibility animation, placement and scaling. */
	final void render(HudContext context, float screenWidth, float screenHeight) {
		boolean visible = isEnabled() && (context.editing() || hasContent(context));
		presence.animateTo(visible ? 1f : 0f);
		float amount = presence.value();
		if (amount <= 0.001f) {
			return;
		}
		float x = x(screenWidth);
		float y = y(screenHeight);
		lastX = x;
		lastY = y;
		var renderer = context.renderer();
		renderer.push();
		renderer.translate(x, y);
		float elementScale = scale.getFloat() * (0.94f + 0.06f * amount);
		renderer.scaleAround(elementScale, 0, 0);
		renderer.pushAlpha(amount);
		try {
			renderContent(context);
		} finally {
			renderer.popAlpha();
			renderer.pop();
		}
	}

	public float lastX() {
		return lastX;
	}

	public float lastY() {
		return lastY;
	}

	public boolean contains(float pointX, float pointY) {
		return pointX >= lastX && pointY >= lastY && pointX <= lastX + scaledWidth() && pointY <= lastY + scaledHeight();
	}

	public boolean isShowing() {
		return presence.value() > 0.001f;
	}
}
