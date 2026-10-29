package dev.nyxveravisuals.setting;

import com.google.gson.JsonElement;
import com.google.gson.JsonPrimitive;

public final class KeybindSetting extends Setting<Keybind> {
	public KeybindSetting(String id, Keybind defaultValue) {
		super(id, defaultValue);
	}

	public void clear() {
		set(Keybind.NONE);
	}

	@Override
	public JsonElement toJson() {
		return new JsonPrimitive(get().serialize());
	}

	@Override
	protected Keybind parse(JsonElement json) {
		return json.isJsonPrimitive() ? Keybind.deserialize(json.getAsString()) : null;
	}
}
