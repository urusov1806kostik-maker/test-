package dev.shadowvisuals.setting;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;

import com.google.gson.JsonElement;

import dev.shadowvisuals.core.Log;

/**
 * A persisted, validated value. Every write goes through {@link #sanitize}, listeners fire only on real
 * changes, and deserialization never throws: invalid input keeps the current value and is logged.
 */
public abstract class Setting<T> extends SettingNode {
	private final T defaultValue;
	private final List<Consumer<T>> listeners = new ArrayList<>(2);
	private T value;

	protected Setting(String id, T defaultValue) {
		super(id);
		this.defaultValue = Objects.requireNonNull(defaultValue, "defaultValue");
		this.value = defaultValue;
	}

	public T get() {
		return value;
	}

	/** Sets a new value after validation. Returns {@code true} if the stored value changed. */
	public final boolean set(T newValue) {
		if (newValue == null) {
			return false;
		}
		T sanitized = sanitize(newValue);
		if (sanitized == null || sanitized.equals(value)) {
			return false;
		}
		value = sanitized;
		for (int i = 0; i < listeners.size(); i++) {
			listeners.get(i).accept(sanitized);
		}
		return true;
	}

	/** Validates and normalizes a candidate value; returning {@code null} rejects it. */
	protected T sanitize(T candidate) {
		return candidate;
	}

	public final T defaultValue() {
		return defaultValue;
	}

	public final boolean isDefault() {
		return value.equals(defaultValue);
	}

	@Override
	public void reset() {
		set(defaultValue);
	}

	public final void onChange(Consumer<T> listener) {
		listeners.add(Objects.requireNonNull(listener));
	}

	public abstract JsonElement toJson();

	/** Parses a JSON value; returns {@code null} when the input is not valid for this setting. */
	protected abstract T parse(JsonElement json);

	public final void load(JsonElement json) {
		T parsed;
		try {
			parsed = json == null || json.isJsonNull() ? null : parse(json);
		} catch (RuntimeException e) {
			parsed = null;
		}
		if (parsed == null) {
			Log.debug("Ignoring invalid value for setting '{}': {}", translationKey(), json);
			return;
		}
		set(parsed);
	}
}
