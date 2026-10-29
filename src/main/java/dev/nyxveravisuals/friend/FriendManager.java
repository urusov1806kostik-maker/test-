package dev.nyxveravisuals.friend;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;

import dev.nyxveravisuals.config.ConfigDocument;

/** Persistent friend list. Lookups are case-insensitive; visual modules only ask {@link #isFriend}. */
public final class FriendManager implements ConfigDocument {
	public static final int MAX_NAME_LENGTH = 32;

	private final Map<String, String> friends = new LinkedHashMap<>();
	private Runnable dirtyHook = () -> { };
	private List<String> snapshot = List.of();

	public void setDirtyHook(Runnable hook) {
		this.dirtyHook = Objects.requireNonNull(hook);
	}

	public static boolean isValidName(String name) {
		if (name == null || name.isEmpty() || name.length() > MAX_NAME_LENGTH) {
			return false;
		}
		for (int i = 0; i < name.length(); i++) {
			char c = name.charAt(i);
			if (Character.isWhitespace(c) || Character.isISOControl(c)) {
				return false;
			}
		}
		return true;
	}

	private static String key(String name) {
		return name.toLowerCase(Locale.ROOT);
	}

	public boolean isFriend(String name) {
		return name != null && friends.containsKey(key(name));
	}

	public boolean add(String name) {
		if (!isValidName(name) || friends.containsKey(key(name))) {
			return false;
		}
		friends.put(key(name), name);
		changed();
		return true;
	}

	public boolean remove(String name) {
		if (name == null || friends.remove(key(name)) == null) {
			return false;
		}
		changed();
		return true;
	}

	/** Adds or removes; returns {@code true} if the player is a friend afterwards. */
	public boolean toggle(String name) {
		if (isFriend(name)) {
			remove(name);
			return false;
		}
		return add(name);
	}

	public void clear() {
		if (!friends.isEmpty()) {
			friends.clear();
			changed();
		}
	}

	public List<String> list() {
		return snapshot;
	}

	private void changed() {
		snapshot = List.copyOf(friends.values());
		dirtyHook.run();
	}

	@Override
	public String fileName() {
		return "friends.json";
	}

	@Override
	public JsonObject save() {
		JsonObject json = new JsonObject();
		JsonArray array = new JsonArray();
		friends.values().forEach(array::add);
		json.add("friends", array);
		return json;
	}

	@Override
	public void load(JsonObject json) {
		friends.clear();
		if (json.has("friends") && json.get("friends").isJsonArray()) {
			for (JsonElement element : json.getAsJsonArray("friends")) {
				if (element.isJsonPrimitive() && isValidName(element.getAsString())) {
					friends.putIfAbsent(key(element.getAsString()), element.getAsString());
				}
			}
		}
		snapshot = List.copyOf(friends.values());
	}

	@Override
	public void loadDefaults() {
		friends.clear();
		snapshot = List.of();
	}
}
