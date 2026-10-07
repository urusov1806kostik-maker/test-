package dev.shadowvisuals.setting;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;

/**
 * Ordered setting tree of one owner (module, HUD element, theme, client preferences). Ids are unique per
 * registry, so persistence is a flat {@code id -> value} map that survives regrouping between versions.
 */
public final class SettingRegistry {
	private final String keyPrefix;
	private final List<SettingNode> roots = new ArrayList<>();
	private final List<SettingNode> rootView = Collections.unmodifiableList(roots);
	private final Map<String, SettingNode> nodes = new LinkedHashMap<>();
	private final Map<String, Setting<?>> values = new LinkedHashMap<>();
	private final List<Runnable> changeListeners = new ArrayList<>(2);

	/** @param keyPrefix translation prefix of the owner, e.g. {@code module.esp} */
	public SettingRegistry(String keyPrefix) {
		this.keyPrefix = Objects.requireNonNull(keyPrefix);
	}

	public String keyPrefix() {
		return keyPrefix;
	}

	public <S extends SettingNode> S add(S node) {
		register(node, null);
		roots.add(node);
		return node;
	}

	public <S extends SettingNode> S add(SettingGroup group, S node) {
		if (nodes.get(group.id()) != group) {
			throw new IllegalArgumentException("Group '" + group.id() + "' is not registered in " + keyPrefix);
		}
		register(node, group);
		group.addChild(node);
		return node;
	}

	private void register(SettingNode node, SettingGroup group) {
		if (nodes.putIfAbsent(node.id(), node) != null) {
			throw new IllegalArgumentException("Duplicate setting id '" + node.id() + "' in " + keyPrefix);
		}
		node.attach(keyPrefix, group);
		if (node instanceof Setting<?> setting) {
			values.put(setting.id(), setting);
			setting.onChange(ignored -> fireChanged());
		}
	}

	private void fireChanged() {
		for (int i = 0; i < changeListeners.size(); i++) {
			changeListeners.get(i).run();
		}
	}

	/** Called after any value in this registry changes (used for autosave and live preview). */
	public void addChangeListener(Runnable listener) {
		changeListeners.add(Objects.requireNonNull(listener));
	}

	public List<SettingNode> roots() {
		return rootView;
	}

	public Collection<Setting<?>> values() {
		return Collections.unmodifiableCollection(values.values());
	}

	public SettingNode find(String id) {
		return nodes.get(id);
	}

	public boolean isEmpty() {
		return nodes.isEmpty();
	}

	public void resetAll() {
		for (Setting<?> setting : values.values()) {
			setting.reset();
		}
	}

	public JsonObject toJson() {
		JsonObject json = new JsonObject();
		for (Setting<?> setting : values.values()) {
			json.add(setting.id(), setting.toJson());
		}
		return json;
	}

	/** Applies stored values; unknown keys are ignored and missing keys keep their defaults. */
	public void load(JsonObject json) {
		if (json == null) {
			return;
		}
		for (Map.Entry<String, JsonElement> entry : json.entrySet()) {
			Setting<?> setting = values.get(entry.getKey());
			if (setting != null) {
				setting.load(entry.getValue());
			}
		}
	}
}
