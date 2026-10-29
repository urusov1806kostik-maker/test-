package dev.nyxveravisuals.config;

import java.util.ArrayList;
import java.util.List;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;

import dev.nyxveravisuals.core.ClientSettings;
import dev.nyxveravisuals.module.ModuleManager;

/** {@code client.json}: global preferences that do not change with the profile. */
public final class ClientPreferences implements ConfigDocument {
	private final ClientSettings settings;
	private final ModuleManager modules;
	private String activeProfile = ProfileManager.DEFAULT;
	private boolean firstLaunchDone;
	private String lastPage = "";
	private boolean loadedFromDisk;

	public ClientPreferences(ClientSettings settings, ModuleManager modules) {
		this.settings = settings;
		this.modules = modules;
	}

	@Override
	public String fileName() {
		return "client.json";
	}

	public String activeProfile() {
		return activeProfile;
	}

	public void setActiveProfile(String name) {
		this.activeProfile = name;
	}

	public boolean firstLaunchDone() {
		return firstLaunchDone;
	}

	public void setFirstLaunchDone(boolean value) {
		this.firstLaunchDone = value;
	}

	/** False when no client.json existed (fresh install) or it was reset because it was broken. */
	public boolean loadedFromDisk() {
		return loadedFromDisk;
	}

	public String lastPage() {
		return lastPage;
	}

	public void setLastPage(String page) {
		this.lastPage = page == null ? "" : page;
	}

	@Override
	public JsonObject save() {
		JsonObject json = new JsonObject();
		json.addProperty("active_profile", activeProfile);
		json.addProperty("first_launch_done", firstLaunchDone);
		json.add("settings", settings.settings().toJson());
		JsonArray favorites = new JsonArray();
		modules.favoriteIds().forEach(favorites::add);
		json.add("favorites", favorites);
		JsonObject gui = new JsonObject();
		gui.addProperty("last_page", lastPage);
		json.add("gui", gui);
		return json;
	}

	@Override
	public void load(JsonObject json) {
		loadedFromDisk = true;
		activeProfile = json.has("active_profile") ? json.get("active_profile").getAsString() : ProfileManager.DEFAULT;
		firstLaunchDone = json.has("first_launch_done") && json.get("first_launch_done").getAsBoolean();
		settings.settings().resetAll();
		if (json.has("settings") && json.get("settings").isJsonObject()) {
			settings.settings().load(json.getAsJsonObject("settings"));
		}
		List<String> favorites = new ArrayList<>();
		if (json.has("favorites") && json.get("favorites").isJsonArray()) {
			for (JsonElement element : json.getAsJsonArray("favorites")) {
				if (element.isJsonPrimitive()) {
					favorites.add(element.getAsString());
				}
			}
		}
		modules.setFavoriteIds(favorites);
		if (json.has("gui") && json.get("gui").isJsonObject()) {
			JsonObject gui = json.getAsJsonObject("gui");
			lastPage = gui.has("last_page") ? gui.get("last_page").getAsString() : "";
		}
	}

	@Override
	public void loadDefaults() {
		loadedFromDisk = false;
		activeProfile = ProfileManager.DEFAULT;
		firstLaunchDone = false;
		lastPage = "";
		settings.settings().resetAll();
		modules.setFavoriteIds(List.of());
	}
}
