package dev.shadowvisuals.setting;

import java.util.Collections;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;

/** Any subset of an enum. The exposed set is immutable; use {@link #toggle} / {@link #set} to change it. */
public final class MultiSelectSetting<E extends Enum<E>> extends Setting<Set<E>> {
	private final Class<E> type;
	private final List<E> options;

	@SafeVarargs
	public MultiSelectSetting(String id, Class<E> type, E... defaults) {
		super(id, immutable(type, defaults.length == 0 ? EnumSet.noneOf(type) : EnumSet.of(defaults[0], defaults)));
		this.type = type;
		this.options = List.of(type.getEnumConstants());
	}

	private static <E extends Enum<E>> Set<E> immutable(Class<E> type, Set<E> values) {
		EnumSet<E> copy = EnumSet.noneOf(type);
		copy.addAll(values);
		return Collections.unmodifiableSet(copy);
	}

	public List<E> options() {
		return options;
	}

	public boolean contains(E option) {
		return get().contains(option);
	}

	public void toggle(E option) {
		EnumSet<E> next = EnumSet.noneOf(type);
		next.addAll(get());
		if (!next.remove(option)) {
			next.add(option);
		}
		set(next);
	}

	@Override
	protected Set<E> sanitize(Set<E> candidate) {
		return immutable(type, candidate);
	}

	@Override
	public JsonElement toJson() {
		JsonArray array = new JsonArray();
		for (E value : get()) {
			array.add(value.name());
		}
		return array;
	}

	@Override
	protected Set<E> parse(JsonElement json) {
		if (!json.isJsonArray()) {
			return null;
		}
		EnumSet<E> result = EnumSet.noneOf(type);
		for (JsonElement element : json.getAsJsonArray()) {
			if (!element.isJsonPrimitive()) {
				continue;
			}
			String name = element.getAsString();
			for (E option : options) {
				if (option.name().equalsIgnoreCase(name)) {
					result.add(option);
				}
			}
		}
		return result;
	}
}
