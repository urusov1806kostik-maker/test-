package dev.nyxveravisuals.setting;

import java.util.function.Predicate;

import com.google.gson.JsonElement;
import com.google.gson.JsonPrimitive;

/** Free text with a length limit and an optional validator; control characters are always stripped. */
public final class StringSetting extends Setting<String> {
	private final int maxLength;
	private Predicate<String> validator = value -> true;

	public StringSetting(String id, String defaultValue, int maxLength) {
		super(id, defaultValue);
		if (maxLength <= 0 || defaultValue.length() > maxLength) {
			throw new IllegalArgumentException("Invalid max length for " + id);
		}
		this.maxLength = maxLength;
	}

	public StringSetting validator(Predicate<String> predicate) {
		this.validator = predicate;
		return this;
	}

	public int maxLength() {
		return maxLength;
	}

	public boolean accepts(String candidate) {
		return validator.test(clean(candidate));
	}

	private String clean(String candidate) {
		StringBuilder builder = new StringBuilder(Math.min(candidate.length(), maxLength));
		for (int i = 0; i < candidate.length() && builder.length() < maxLength; i++) {
			char c = candidate.charAt(i);
			if (!Character.isISOControl(c)) {
				builder.append(c);
			}
		}
		return builder.toString();
	}

	@Override
	protected String sanitize(String candidate) {
		String cleaned = clean(candidate);
		return validator.test(cleaned) ? cleaned : null;
	}

	@Override
	public JsonElement toJson() {
		return new JsonPrimitive(get());
	}

	@Override
	protected String parse(JsonElement json) {
		return json.isJsonPrimitive() ? json.getAsString() : null;
	}
}
