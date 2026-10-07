package dev.shadowvisuals.util;

public final class MathUtil {
	private MathUtil() {
	}

	public static float clamp(float value, float min, float max) {
		return value < min ? min : Math.min(value, max);
	}

	public static double clamp(double value, double min, double max) {
		return value < min ? min : Math.min(value, max);
	}

	public static int clamp(int value, int min, int max) {
		return value < min ? min : Math.min(value, max);
	}

	public static float lerp(float from, float to, float t) {
		return from + (to - from) * t;
	}

	public static double lerp(double from, double to, double t) {
		return from + (to - from) * t;
	}

	/** Frame-rate independent exponential approach: identical motion at 30 or 300 FPS. */
	public static float approach(float current, float target, float speed, float deltaSeconds) {
		if (speed <= 0 || deltaSeconds <= 0) {
			return current;
		}
		float factor = 1f - (float) Math.exp(-speed * deltaSeconds);
		float next = current + (target - current) * factor;
		return Math.abs(target - next) < 1e-4f ? target : next;
	}

	public static float inverseLerp(float from, float to, float value) {
		return from == to ? 0f : clamp((value - from) / (to - from), 0f, 1f);
	}

	/** Wraps degrees to {@code [-180, 180)}. */
	public static float wrapDegrees(float degrees) {
		float wrapped = degrees % 360f;
		if (wrapped >= 180f) {
			wrapped -= 360f;
		}
		if (wrapped < -180f) {
			wrapped += 360f;
		}
		return wrapped;
	}
}
