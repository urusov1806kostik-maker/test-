package dev.shadowvisuals.setting;

import com.google.gson.JsonElement;
import com.google.gson.JsonPrimitive;

public final class BooleanSetting extends Setting<Boolean> {
	public BooleanSetting(String id, boolean defaultValue) {
		super(id, defaultValue);
	}

	public boolean isOn() {
		return get();
	}

	public void toggle() {
		set(!get());
	}

	@Override
	public JsonElement toJson() {
		return new JsonPrimitive(get());
	}

	@Override
	protected Boolean parse(JsonElement json) {
		if (json.isJsonPrimitive() && json.getAsJsonPrimitive().isBoolean()) {
			return json.getAsBoolean();
		}
		return null;
	}
}
