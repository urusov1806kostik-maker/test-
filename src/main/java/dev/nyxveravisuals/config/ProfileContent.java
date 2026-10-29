package dev.nyxveravisuals.config;

import com.google.gson.JsonObject;

import dev.nyxveravisuals.module.ModuleManager;
import dev.nyxveravisuals.theme.ThemeManager;

/**
 * Contents of one profile: every module (enabled state, binds, settings, HUD layout) and the theme. The
 * file name is managed by {@link ProfileManager}.
 */
public final class ProfileContent implements ConfigDocument {
	private final ModuleManager modules;
	private final ThemeManager theme;

	public ProfileContent(ModuleManager modules, ThemeManager theme) {
		this.modules = modules;
		this.theme = theme;
	}

	@Override
	public String fileName() {
		return "profile";
	}

	@Override
	public JsonObject save() {
		JsonObject json = new JsonObject();
		json.add("modules", modules.toJson());
		json.add("theme", theme.toJson());
		return json;
	}

	@Override
	public void load(JsonObject json) {
		modules.load(json.has("modules") && json.get("modules").isJsonObject() ? json.getAsJsonObject("modules") : new JsonObject());
		if (json.has("theme") && json.get("theme").isJsonObject()) {
			theme.load(json.getAsJsonObject("theme"));
		} else {
			theme.reset();
		}
	}

	@Override
	public void loadDefaults() {
		modules.resetAll();
		theme.reset();
	}
}
