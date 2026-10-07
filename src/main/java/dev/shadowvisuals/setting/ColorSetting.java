package dev.shadowvisuals.setting;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;

import dev.shadowvisuals.animation.AnimationClock;
import dev.shadowvisuals.util.ColorUtil;

/** ARGB color with an optional, user-enabled rainbow mode. Use {@link #color()} when rendering. */
public final class ColorSetting extends Setting<ColorSetting.Value> {
	/** @param rainbowSpeed hue cycles per 10 seconds */
	public record Value(int argb, boolean rainbow, float rainbowSpeed) {
		public Value withArgb(int value) {
			return new Value(value, rainbow, rainbowSpeed);
		}

		public Value withRainbow(boolean value) {
			return new Value(argb, value, rainbowSpeed);
		}

		public Value withRainbowSpeed(float value) {
			return new Value(argb, rainbow, value);
		}
	}

	public static final float MIN_RAINBOW_SPEED = 0.5f;
	public static final float MAX_RAINBOW_SPEED = 10f;

	private final boolean allowAlpha;

	public ColorSetting(String id, int defaultArgb) {
		this(id, defaultArgb, true);
	}

	public ColorSetting(String id, int defaultArgb, boolean allowAlpha) {
		super(id, new Value(allowAlpha ? defaultArgb : defaultArgb | 0xFF000000, false, 2f));
		this.allowAlpha = allowAlpha;
	}

	public boolean allowAlpha() {
		return allowAlpha;
	}

	public int argb() {
		return get().argb();
	}

	public boolean isRainbow() {
		return get().rainbow();
	}

	/** Effective color for this frame (rainbow applied when enabled). */
	public int color() {
		return color(0f);
	}

	/** Effective color with a hue offset, so lists can show a flowing rainbow. */
	public int color(float hueOffset) {
		Value value = get();
		if (!value.rainbow()) {
			return value.argb();
		}
		return ColorUtil.rainbowOf(value.argb(), AnimationClock.global().now(), value.rainbowSpeed(), hueOffset);
	}

	public void setArgb(int argb) {
		set(get().withArgb(argb));
	}

	@Override
	protected Value sanitize(Value candidate) {
		int argb = allowAlpha ? candidate.argb() : candidate.argb() | 0xFF000000;
		float speed = Float.isFinite(candidate.rainbowSpeed())
			? Math.max(MIN_RAINBOW_SPEED, Math.min(MAX_RAINBOW_SPEED, candidate.rainbowSpeed()))
			: 2f;
		return new Value(argb, candidate.rainbow(), speed);
	}

	@Override
	public JsonElement toJson() {
		JsonObject json = new JsonObject();
		json.addProperty("color", ColorUtil.toHex(argb(), true));
		json.addProperty("rainbow", get().rainbow());
		json.addProperty("rainbow_speed", get().rainbowSpeed());
		return json;
	}

	@Override
	protected Value parse(JsonElement json) {
		if (json.isJsonPrimitive()) {
			Integer argb = ColorUtil.parseHex(json.getAsString());
			return argb == null ? null : new Value(argb, false, get().rainbowSpeed());
		}
		if (!json.isJsonObject()) {
			return null;
		}
		JsonObject object = json.getAsJsonObject();
		Integer argb = object.has("color") ? ColorUtil.parseHex(object.get("color").getAsString()) : null;
		if (argb == null) {
			return null;
		}
		boolean rainbow = object.has("rainbow") && object.get("rainbow").getAsBoolean();
		float speed = object.has("rainbow_speed") ? object.get("rainbow_speed").getAsFloat() : get().rainbowSpeed();
		return new Value(argb, rainbow, speed);
	}
}
