package dev.shadowvisuals.util;

import java.util.Locale;

/** Centralized ARGB color math. All colors are packed {@code 0xAARRGGBB} ints. */
public final class ColorUtil {
	private ColorUtil() {
	}

	public static int argb(int alpha, int red, int green, int blue) {
		return (clamp255(alpha) << 24) | (clamp255(red) << 16) | (clamp255(green) << 8) | clamp255(blue);
	}

	public static int rgb(int rgb) {
		return 0xFF000000 | (rgb & 0xFFFFFF);
	}

	public static int alpha(int color) {
		return color >>> 24;
	}

	public static int red(int color) {
		return (color >> 16) & 0xFF;
	}

	public static int green(int color) {
		return (color >> 8) & 0xFF;
	}

	public static int blue(int color) {
		return color & 0xFF;
	}

	private static int clamp255(int value) {
		return value < 0 ? 0 : Math.min(value, 255);
	}

	public static int withAlpha(int color, int alpha) {
		return (clamp255(alpha) << 24) | (color & 0xFFFFFF);
	}

	/** Multiplies the existing alpha by {@code factor} ({@code 0..1}). */
	public static int fade(int color, float factor) {
		if (factor >= 1f) {
			return color;
		}
		int alpha = Math.round(alpha(color) * Math.max(0f, factor));
		return (alpha << 24) | (color & 0xFFFFFF);
	}

	public static int lerp(int from, int to, float t) {
		if (t <= 0f) {
			return from;
		}
		if (t >= 1f) {
			return to;
		}
		return argb(
			Math.round(alpha(from) + (alpha(to) - alpha(from)) * t),
			Math.round(red(from) + (red(to) - red(from)) * t),
			Math.round(green(from) + (green(to) - green(from)) * t),
			Math.round(blue(from) + (blue(to) - blue(from)) * t));
	}

	/** Samples evenly spaced gradient stops at {@code t} in {@code 0..1}. */
	public static int gradient(float t, int... stops) {
		if (stops.length == 0) {
			return 0;
		}
		if (stops.length == 1) {
			return stops[0];
		}
		float clamped = Math.max(0f, Math.min(1f, t));
		float scaled = clamped * (stops.length - 1);
		int index = Math.min((int) scaled, stops.length - 2);
		return lerp(stops[index], stops[index + 1], scaled - index);
	}

	/** HSV to ARGB; hue wraps, saturation/value are clamped to {@code 0..1}. */
	public static int fromHsv(float hue, float saturation, float value, int alpha) {
		float h = hue - (float) Math.floor(hue);
		float s = Math.max(0f, Math.min(1f, saturation));
		float v = Math.max(0f, Math.min(1f, value));
		float c = v * s;
		float x = c * (1 - Math.abs((h * 6f) % 2f - 1));
		float m = v - c;
		float r;
		float g;
		float b;
		switch ((int) (h * 6f)) {
			case 0 -> { r = c; g = x; b = 0; }
			case 1 -> { r = x; g = c; b = 0; }
			case 2 -> { r = 0; g = c; b = x; }
			case 3 -> { r = 0; g = x; b = c; }
			case 4 -> { r = x; g = 0; b = c; }
			default -> { r = c; g = 0; b = x; }
		}
		return argb(alpha, Math.round((r + m) * 255), Math.round((g + m) * 255), Math.round((b + m) * 255));
	}

	/** Writes {@code hue, saturation, value} (each {@code 0..1}) into {@code out} and returns it. */
	public static float[] toHsv(int color, float[] out) {
		float r = red(color) / 255f;
		float g = green(color) / 255f;
		float b = blue(color) / 255f;
		float max = Math.max(r, Math.max(g, b));
		float min = Math.min(r, Math.min(g, b));
		float delta = max - min;
		float hue;
		if (delta == 0) {
			hue = 0;
		} else if (max == r) {
			hue = ((g - b) / delta) / 6f;
		} else if (max == g) {
			hue = ((b - r) / delta + 2f) / 6f;
		} else {
			hue = ((r - g) / delta + 4f) / 6f;
		}
		if (hue < 0) {
			hue += 1f;
		}
		out[0] = hue;
		out[1] = max == 0 ? 0 : delta / max;
		out[2] = max;
		return out;
	}

	/** Scales HSV value; factors above 1 brighten, below 1 darken. */
	public static int brightness(int color, float factor) {
		float[] hsv = toHsv(color, new float[3]);
		return fromHsv(hsv[0], hsv[1], hsv[2] * factor, alpha(color));
	}

	public static int saturation(int color, float factor) {
		float[] hsv = toHsv(color, new float[3]);
		return fromHsv(hsv[0], hsv[1] * factor, hsv[2], alpha(color));
	}

	/** Mixes towards white ({@code amount > 0}) or black ({@code amount < 0}); keeps alpha. */
	public static int shade(int color, float amount) {
		int target = amount >= 0 ? 0xFFFFFFFF : 0xFF000000;
		int mixed = lerp(color | 0xFF000000, target, Math.abs(amount));
		return (color & 0xFF000000) | (mixed & 0xFFFFFF);
	}

	/** Hue cycling color; {@code speed} is cycles per 10 seconds, {@code offset} shifts hue (0..1). */
	public static int rainbow(double timeSeconds, float speed, float offset, float saturation, float value, int alpha) {
		double hue = timeSeconds * speed / 10.0 + offset;
		return fromHsv((float) (hue - Math.floor(hue)), saturation, value, alpha);
	}

	/** Keeps the saturation/value/alpha of {@code base} but rotates its hue over time. */
	public static int rainbowOf(int base, double timeSeconds, float speed, float offset) {
		float[] hsv = toHsv(base, new float[3]);
		float saturation = hsv[1] < 0.2f ? 0.65f : hsv[1];
		float value = hsv[2] < 0.2f ? 0.9f : hsv[2];
		return rainbow(timeSeconds, speed, offset, saturation, value, alpha(base));
	}

	/** Smoothly pulses brightness between {@code minFactor} and 1 at {@code speed} pulses per second. */
	public static int pulse(int color, double timeSeconds, float speed, float minFactor) {
		float wave = (float) (0.5 + 0.5 * Math.sin(timeSeconds * speed * Math.PI * 2));
		return lerp(shade(color, -(1f - minFactor)), color, wave);
	}

	/** Perceived luminance (Rec. 709) in {@code 0..1}. */
	public static float luminance(int color) {
		return (0.2126f * red(color) + 0.7152f * green(color) + 0.0722f * blue(color)) / 255f;
	}

	public static int readableTextOn(int background) {
		return luminance(background) > 0.6f ? 0xFF111217 : 0xFFF2F3F7;
	}

	public static String toHex(int color, boolean withAlpha) {
		return withAlpha
			? String.format(Locale.ROOT, "#%08X", color)
			: String.format(Locale.ROOT, "#%06X", color & 0xFFFFFF);
	}

	/** Parses {@code #RGB}, {@code #RRGGBB} or {@code #AARRGGBB}; returns {@code null} when invalid. */
	public static Integer parseHex(String text) {
		if (text == null) {
			return null;
		}
		String value = text.trim();
		if (value.startsWith("#")) {
			value = value.substring(1);
		}
		if (!value.matches("[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8}")) {
			return null;
		}
		if (value.length() == 3) {
			value = "" + value.charAt(0) + value.charAt(0) + value.charAt(1) + value.charAt(1) + value.charAt(2) + value.charAt(2);
		}
		long parsed = Long.parseLong(value, 16);
		return value.length() == 6 ? (int) (0xFF000000L | parsed) : (int) parsed;
	}
}
