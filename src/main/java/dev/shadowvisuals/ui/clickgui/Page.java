package dev.shadowvisuals.ui.clickgui;

import java.util.Locale;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.ui.Icon;

/** Sidebar destinations: favorites, every module category, then the config and settings pages. */
public enum Page {
	FAVORITES(Icon.STAR, null),
	VISUAL(Icon.EYE, Category.VISUAL),
	HUD(Icon.LAYOUT, Category.HUD),
	WORLD(Icon.GLOBE, Category.WORLD),
	PLAYER(Icon.USER, Category.PLAYER),
	CAMERA(Icon.CAMERA, Category.CAMERA),
	INTERFACE(Icon.WINDOW, Category.INTERFACE),
	UTILITY(Icon.TOOL, Category.UTILITY),
	FUNTIME(Icon.BOLT, Category.FUNTIME),
	CONFIG(Icon.FOLDER, null),
	SETTINGS(Icon.SLIDERS, null);

	private final Icon icon;
	private final Category category;

	Page(Icon icon, Category category) {
		this.icon = icon;
		this.category = category;
	}

	public Icon icon() {
		return icon;
	}

	/** Module category shown on this page, or {@code null} for special pages. */
	public Category category() {
		return category;
	}

	public String translationKey() {
		return category != null ? category.translationKey() : "page." + name().toLowerCase(Locale.ROOT);
	}

	public boolean startsSection() {
		return this == CONFIG;
	}

	/** The page that lists {@code category}; every category has exactly one. */
	public static Page of(Category category) {
		for (Page page : values()) {
			if (page.category == category) {
				return page;
			}
		}
		return VISUAL;
	}

	public static Page byName(String name) {
		for (Page page : values()) {
			if (page.name().equalsIgnoreCase(name)) {
				return page;
			}
		}
		return VISUAL;
	}
}
