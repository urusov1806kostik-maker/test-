package dev.shadowvisuals.module;

import java.util.Locale;

/** Module categories shown in the ClickGUI sidebar. */
public enum Category {
	VISUAL,
	HUD,
	WORLD,
	PLAYER,
	CAMERA,
	INTERFACE,
	UTILITY,
	FUNTIME;

	public String id() {
		return name().toLowerCase(Locale.ROOT);
	}

	public String translationKey() {
		return "category." + id();
	}
}
