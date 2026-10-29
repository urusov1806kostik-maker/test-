package dev.nyxveravisuals.setting;

import java.util.Locale;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;

/** Two-handle range inside {@code [min, max]}; {@code low <= high} is always enforced. */
public final class RangeSetting extends Setting<RangeSetting.Range> {
	public record Range(double low, double high) {
	}

	private final double min;
	private final double max;
	private final double step;
	private final int decimals;
	private String suffix = "";

	public RangeSetting(String id, double low, double high, double min, double max, double step) {
		super(id, new Range(low, high));
		if (!(min < max) || !(step > 0) || low > high || low < min || high > max) {
			throw new IllegalArgumentException("Invalid range setting bounds for " + id);
		}
		this.min = min;
		this.max = max;
		this.step = step;
		this.decimals = NumberSetting.decimalsOf(step);
	}

	public RangeSetting suffix(String value) {
		this.suffix = value == null ? "" : value;
		return this;
	}

	public double min() {
		return min;
	}

	public double max() {
		return max;
	}

	public double low() {
		return get().low();
	}

	public double high() {
		return get().high();
	}

	public void setLow(double value) {
		set(new Range(value, Math.max(value, high())));
	}

	public void setHigh(double value) {
		set(new Range(Math.min(value, low()), value));
	}

	private double snap(double value) {
		double clamped = Math.max(min, Math.min(max, value));
		double snapped = min + Math.round((clamped - min) / step) * step;
		double scale = Math.pow(10, decimals);
		return Math.round(Math.max(min, Math.min(max, snapped)) * scale) / scale;
	}

	@Override
	protected Range sanitize(Range candidate) {
		if (!Double.isFinite(candidate.low()) || !Double.isFinite(candidate.high())) {
			return null;
		}
		double low = snap(candidate.low());
		double high = snap(candidate.high());
		return low <= high ? new Range(low, high) : new Range(high, low);
	}

	public String format() {
		String pattern = "%." + decimals + "f";
		return String.format(Locale.ROOT, pattern, low()) + " – " + String.format(Locale.ROOT, pattern, high()) + suffix;
	}

	@Override
	public JsonElement toJson() {
		JsonArray array = new JsonArray();
		array.add(low());
		array.add(high());
		return array;
	}

	@Override
	protected Range parse(JsonElement json) {
		if (!json.isJsonArray() || json.getAsJsonArray().size() != 2) {
			return null;
		}
		JsonArray array = json.getAsJsonArray();
		return new Range(array.get(0).getAsDouble(), array.get(1).getAsDouble());
	}
}
