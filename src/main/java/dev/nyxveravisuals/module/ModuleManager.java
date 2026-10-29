package dev.nyxveravisuals.module;

import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.UnaryOperator;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;

import dev.nyxveravisuals.core.Log;
import dev.nyxveravisuals.event.EventBus;
import dev.nyxveravisuals.setting.Keybind;

/**
 * Owns the module registry, binds, favorites and module persistence. It knows nothing about any GUI:
 * screens read its state and observe it through {@link Listener}.
 */
public final class ModuleManager implements ModuleHost {
	public interface Listener {
		default void onModuleToggled(Module module, boolean enabled) {
		}

		default void onModuleFailed(Module module, String phase, Throwable error) {
		}
	}

	private final EventBus eventBus;
	private final Map<String, Module> byId = new LinkedHashMap<>();
	private final Map<Class<? extends Module>, Module> byType = new HashMap<>();
	private final Map<Category, List<Module>> byCategory = new EnumMap<>(Category.class);
	private final Set<String> favorites = new LinkedHashSet<>();
	private final List<Listener> listeners = new ArrayList<>();
	private List<Module> all = List.of();
	private Runnable dirtyHook = () -> { };
	private boolean silent;

	public ModuleManager(EventBus eventBus) {
		this.eventBus = Objects.requireNonNull(eventBus);
		for (Category category : Category.values()) {
			byCategory.put(category, new ArrayList<>());
		}
	}

	public void setDirtyHook(Runnable hook) {
		this.dirtyHook = Objects.requireNonNull(hook);
	}

	public void addListener(Listener listener) {
		listeners.add(Objects.requireNonNull(listener));
	}

	public <M extends Module> M register(M module) {
		if (byId.containsKey(module.id())) {
			throw new IllegalArgumentException("Duplicate module id: " + module.id());
		}
		module.attach(this);
		byId.put(module.id(), module);
		byType.put(module.getClass(), module);
		byCategory.get(module.category()).add(module);
		all = List.copyOf(byId.values());
		module.settings().addChangeListener(dirtyHook::run);
		return module;
	}

	@Override
	public EventBus eventBus() {
		return eventBus;
	}

	@Override
	public void onModuleToggled(Module module, boolean enabled) {
		dirtyHook.run();
		if (silent) {
			return;
		}
		for (Listener listener : listeners) {
			listener.onModuleToggled(module, enabled);
		}
	}

	@Override
	public void onModuleFailure(Module module, String phase, Throwable error) {
		Log.error("Module '{}' failed during {} and was disabled", module.id(), phase, error);
		for (Listener listener : listeners) {
			listener.onModuleFailed(module, phase, error);
		}
	}

	/** Event-bus error routing: a crashing listener disables its owning module only. */
	public boolean handleListenerError(Object owner, Object event, Throwable error) {
		if (!(owner instanceof Module module)) {
			return false;
		}
		Log.error("Module '{}' crashed while handling {}; disabling it", module.id(), event.getClass().getSimpleName(), error);
		module.fail();
		for (Listener listener : listeners) {
			listener.onModuleFailed(module, "event", error);
		}
		return true;
	}

	public List<Module> all() {
		return all;
	}

	public List<Module> inCategory(Category category) {
		return Collections.unmodifiableList(byCategory.get(category));
	}

	public Module byId(String id) {
		return byId.get(id);
	}

	@SuppressWarnings("unchecked")
	public <M extends Module> M get(Class<M> type) {
		return (M) byType.get(type);
	}

	public boolean isEnabled(Class<? extends Module> type) {
		Module module = byType.get(type);
		return module != null && module.isEnabled();
	}

	public boolean isFavorite(Module module) {
		return favorites.contains(module.id());
	}

	public void toggleFavorite(Module module) {
		if (!favorites.remove(module.id())) {
			favorites.add(module.id());
		}
		dirtyHook.run();
	}

	public List<Module> favorites() {
		List<Module> result = new ArrayList<>(favorites.size());
		for (String id : favorites) {
			Module module = byId.get(id);
			if (module != null) {
				result.add(module);
			}
		}
		return result;
	}

	/** Routes a raw input press/release to module binds. Returns true when a bind consumed it. */
	public boolean handleBind(Keybind.Device device, int code, boolean pressed) {
		boolean consumed = false;
		for (Module module : all) {
			if (!module.isToggleable() || !module.bind().get().matches(device, code)) {
				continue;
			}
			if (module.bindMode().get() == Module.BindMode.HOLD) {
				module.setEnabled(pressed);
				consumed = true;
			} else if (pressed) {
				module.toggle();
				consumed = true;
			}
		}
		return consumed;
	}

	/** Releases all hold-mode modules, e.g. when a screen opens or the window loses focus. */
	public void releaseHeldBinds() {
		for (Module module : all) {
			if (module.bindMode().get() == Module.BindMode.HOLD && module.bind().get().isBound() && module.isEnabled()) {
				module.setEnabled(false);
			}
		}
	}

	/**
	 * Case-insensitive search over localized name, description and category name.
	 *
	 * @param translator maps translation keys to display text in the current language
	 */
	public List<Module> search(String query, UnaryOperator<String> translator) {
		String needle = query == null ? "" : query.trim().toLowerCase(Locale.ROOT);
		if (needle.isEmpty()) {
			return all;
		}
		List<Module> nameMatches = new ArrayList<>();
		List<Module> otherMatches = new ArrayList<>();
		for (Module module : all) {
			String name = translator.apply(module.nameKey()).toLowerCase(Locale.ROOT);
			if (name.contains(needle) || module.id().contains(needle)) {
				nameMatches.add(module);
				continue;
			}
			String description = translator.apply(module.descriptionKey()).toLowerCase(Locale.ROOT);
			String category = translator.apply(module.category().translationKey()).toLowerCase(Locale.ROOT);
			if (description.contains(needle) || category.contains(needle)) {
				otherMatches.add(module);
			}
		}
		nameMatches.addAll(otherMatches);
		return nameMatches;
	}

	/** Disables everything (used on shutdown and before applying a different profile). */
	public void disableAll() {
		silent = true;
		try {
			for (Module module : all) {
				module.setEnabled(false);
			}
		} finally {
			silent = false;
		}
	}

	public void resetAll() {
		silent = true;
		try {
			for (Module module : all) {
				module.settings().resetAll();
				module.setEnabled(module.enabledByDefault());
			}
		} finally {
			silent = false;
		}
	}

	public JsonObject toJson() {
		JsonObject json = new JsonObject();
		for (Module module : all) {
			JsonObject entry = new JsonObject();
			entry.addProperty("enabled", module.isEnabled());
			entry.add("settings", module.settings().toJson());
			json.add(module.id(), entry);
		}
		return json;
	}

	/** Applies a saved module section; modules missing from it get their defaults. */
	public void load(JsonObject json) {
		silent = true;
		try {
			for (Module module : all) {
				JsonElement element = json == null ? null : json.get(module.id());
				module.settings().resetAll();
				if (element == null || !element.isJsonObject()) {
					module.setEnabled(module.enabledByDefault());
					continue;
				}
				JsonObject entry = element.getAsJsonObject();
				if (entry.has("settings") && entry.get("settings").isJsonObject()) {
					module.settings().load(entry.getAsJsonObject("settings"));
				}
				boolean enabled = entry.has("enabled") && entry.get("enabled").isJsonPrimitive()
					? entry.get("enabled").getAsBoolean()
					: module.enabledByDefault();
				module.setEnabled(enabled);
			}
		} finally {
			silent = false;
		}
	}

	public Set<String> favoriteIds() {
		return Collections.unmodifiableSet(favorites);
	}

	public void setFavoriteIds(Iterable<String> ids) {
		favorites.clear();
		for (String id : ids) {
			favorites.add(id);
		}
	}
}
