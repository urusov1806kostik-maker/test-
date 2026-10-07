package dev.shadowvisuals.setting;

import com.google.gson.JsonElement;
import com.google.gson.JsonPrimitive;

/** Integer setting clamped to {@code [min, max]} and snapped to {@code step}. */
public final class IntSetting extends Setting<Integer> {
	private final int min;
	private final int max;
	private final int step;
	private String suffix = "";

	public IntSetting(String id, int defaultValue, int min, int max) {
		this(id, defaultValue, min, max, 1);
	}

	public IntSetting(String id, int defaultValue, int min, int max, int step) {
		super(id, defaultValue);
		if (min >= max || step <= 0 || defaultValue < min || defaultValue > max) {
			throw new IllegalArgumentException("Invalid int setting bounds for " + id);
		}
		this.min = min;
		this.max = max;
		this.step = step;
	}

	public IntSetting suffix(String value) {
		this.suffix = value == null ? "" : value;
		return this;
	}

	public String suffix() {
		return suffix;
	}

	public int min() {
		return min;
	}

	public int max() {
		return max;
	}

	public int step() {
		return step;
	}

	public int getInt() {
		return get();
	}

	public double progress() {
		return (double) (get() - min) / (max - min);
	}

	public void setProgress(double progress) {
		set((int) Math.round(min + Math.max(0, Math.min(1, progress)) * (max - min)));
	}

	@Override
	protected Integer sanitize(Integer candidate) {
		int value = Math.max(min, Math.min(max, candidate));
		value = min + Math.round((value - min) / (float) step) * step;
		return Math.max(min, Math.min(max, value));
	}

	public String format() {
		return get() + suffix;
	}

	@Override
	public JsonElement toJson() {
		return new JsonPrimitive(get());
	}

	@Override
	protected Integer parse(JsonElement json) {
		if (json.isJsonPrimitive() && json.getAsJsonPrimitive().isNumber()) {
			double value = json.getAsDouble();
			return Double.isFinite(value) ? (int) Math.round(value) : null;
		}
		return null;
	}
}
