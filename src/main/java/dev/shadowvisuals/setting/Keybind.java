package dev.shadowvisuals.setting;

/**
 * Device-agnostic binding. Codes are GLFW key codes for {@link Device#KEYBOARD} and GLFW button indices for
 * {@link Device#MOUSE}; {@link #NONE} means unbound.
 */
public record Keybind(Device device, int code) {
	public enum Device {
		NONE,
		KEYBOARD,
		MOUSE
	}

	public static final Keybind NONE = new Keybind(Device.NONE, -1);

	public static Keybind key(int glfwKey) {
		return new Keybind(Device.KEYBOARD, glfwKey);
	}

	public static Keybind mouse(int glfwButton) {
		return new Keybind(Device.MOUSE, glfwButton);
	}

	public boolean isBound() {
		return device != Device.NONE;
	}

	public boolean matches(Device inputDevice, int inputCode) {
		return device == inputDevice && code == inputCode && isBound();
	}

	/** Compact persisted form: {@code none}, {@code key:<code>} or {@code mouse:<code>}. */
	public String serialize() {
		return switch (device) {
			case NONE -> "none";
			case KEYBOARD -> "key:" + code;
			case MOUSE -> "mouse:" + code;
		};
	}

	public static Keybind deserialize(String text) {
		if (text == null || text.equalsIgnoreCase("none")) {
			return NONE;
		}
		int separator = text.indexOf(':');
		if (separator <= 0) {
			return null;
		}
		try {
			int code = Integer.parseInt(text.substring(separator + 1));
			return switch (text.substring(0, separator)) {
				case "key" -> code >= 0 ? key(code) : null;
				case "mouse" -> code >= 0 ? mouse(code) : null;
				default -> null;
			};
		} catch (NumberFormatException e) {
			return null;
		}
	}
}
