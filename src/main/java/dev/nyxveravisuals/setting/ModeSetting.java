package dev.nyxveravisuals.setting;

import java.util.List;
import java.util.Locale;

import com.google.gson.JsonElement;
import com.google.gson.JsonPrimitive;

/** Single choice from an enum. Persisted by constant name, so reordering constants is safe. */
public final class ModeSetting<E extends Enum<E>> extends Setting<E> {
	private final List<E> modes;

	public ModeSetting(String id, E defaultValue) {
		super(id, defaultValue);
		this.modes = List.of(defaultValue.getDeclaringClass().getEnumConstants());
	}

	public List<E> modes() {
		return modes;
	}

	public boolean is(E mode) {
		return get() == mode;
	}

	public void cycle(int direction) {
		int index = Math.floorMod(get().ordinal() + Integer.signum(direction == 0 ? 1 : direction), modes.size());
		set(modes.get(index));
	}

	/** Translation key of an enum constant, e.g. {@code enum.esp_style.box_2d}. */
	public static String keyOf(Enum<?> constant) {
		return "enum." + snake(constant.getDeclaringClass().getSimpleName()) + "." + constant.name().toLowerCase(Locale.ROOT);
	}

	static String snake(String camel) {
		StringBuilder builder = new StringBuilder(camel.length() + 4);
		for (int i = 0; i < camel.length(); i++) {
			char c = camel.charAt(i);
			if (Character.isUpperCase(c)) {
				if (i > 0) {
					builder.append('_');
				}
				builder.append(Character.toLowerCase(c));
			} else {
				builder.append(c);
			}
		}
		return builder.toString();
	}

	@Override
	public JsonElement toJson() {
		return new JsonPrimitive(get().name());
	}

	@Override
	protected E parse(JsonElement json) {
		if (!json.isJsonPrimitive()) {
			return null;
		}
		String name = json.getAsString();
		for (E mode : modes) {
			if (mode.name().equalsIgnoreCase(name)) {
				return mode;
			}
		}
		return null;
	}
}
