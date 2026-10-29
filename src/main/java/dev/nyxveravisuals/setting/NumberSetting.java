package dev.nyxveravisuals.setting;

import com.google.gson.JsonElement;
import com.google.gson.JsonPrimitive;

/** Floating point setting clamped to {@code [min, max]} and snapped to {@code step}. */
public final class NumberSetting extends Setting<Double> {
	private final double min;
	private final double max;
	private final double step;
	private final int decimals;
	private String suffix = "";

	public NumberSetting(String id, double defaultValue, double min, double max, double step) {
		super(id, validateDefault(defaultValue, min, max, step));
		this.min = min;
		this.max = max;
		this.step = step;
		this.decimals = decimalsOf(step);
	}

	private static double validateDefault(double value, double min, double max, double step) {
		if (!(min < max) || !(step > 0) || value < min || value > max) {
			throw new IllegalArgumentException("Invalid number setting bounds: " + value + " in [" + min + ", " + max + "] step " + step);
		}
		return value;
	}

	static int decimalsOf(double step) {
		int decimals = 0;
		double scaled = step;
		while (decimals < 6 && Math.abs(scaled - Math.rint(scaled)) > 1e-9) {
			scaled *= 10;
			decimals++;
		}
		return decimals;
	}

	public NumberSetting suffix(String value) {
		this.suffix = value == null ? "" : value;
		return this;
	}

	public String suffix() {
		return suffix;
	}

	public double min() {
		return min;
	}

	public double max() {
		return max;
	}

	public double step() {
		return step;
	}

	public int decimals() {
		return decimals;
	}

	public float getFloat() {
		return get().floatValue();
	}

	public double getDouble() {
		return get();
	}

	/** Position of the value inside the range, {@code 0..1}. */
	public double progress() {
		return (get() - min) / (max - min);
	}

	public void setProgress(double progress) {
		set(min + Math.max(0, Math.min(1, progress)) * (max - min));
	}

	@Override
	protected Double sanitize(Double candidate) {
		double value = candidate;
		if (Double.isNaN(value) || Double.isInfinite(value)) {
			return null;
		}
		value = Math.max(min, Math.min(max, value));
		value = min + Math.round((value - min) / step) * step;
		value = Math.max(min, Math.min(max, value));
		double scale = Math.pow(10, decimals);
		return Math.round(value * scale) / scale;
	}

	public String format() {
		return String.format(java.util.Locale.ROOT, "%." + decimals + "f", get()) + suffix;
	}

	@Override
	public JsonElement toJson() {
		return new JsonPrimitive(get());
	}

	@Override
	protected Double parse(JsonElement json) {
		if (json.isJsonPrimitive() && json.getAsJsonPrimitive().isNumber()) {
			return json.getAsDouble();
		}
		return null;
	}
}
