package dev.shadowvisuals.setting;

import java.util.Objects;
import java.util.function.BooleanSupplier;

/**
 * Base of the setting tree. A node knows its stable id, its translation key (assigned when attached to a
 * {@link SettingRegistry}) and when it should be visible. Values live in {@link Setting}; groups and
 * actions are structural nodes without a persisted value.
 */
public abstract class SettingNode {
	private static final BooleanSupplier ALWAYS = () -> true;

	private final String id;
	private String translationKey;
	private BooleanSupplier visibility = ALWAYS;
	private SettingGroup parent;
	private boolean internal;

	protected SettingNode(String id) {
		if (id == null || !id.matches("[a-z0-9_]+")) {
			throw new IllegalArgumentException("Setting id must be snake_case: " + id);
		}
		this.id = id;
		this.translationKey = "setting." + id;
	}

	public final String id() {
		return id;
	}

	/** Translation key of the display name, e.g. {@code module.esp.setting.range}. */
	public final String translationKey() {
		return translationKey;
	}

	/** Shared fallback key ({@code setting.<id>}) used when no owner-specific translation exists. */
	public final String genericTranslationKey() {
		return "setting." + id;
	}

	public final String descriptionKey() {
		return translationKey + ".desc";
	}

	public final SettingGroup parent() {
		return parent;
	}

	/** Visible only when the condition holds and every parent group is visible. */
	@SuppressWarnings("unchecked")
	public final <S extends SettingNode> S visibleWhen(BooleanSupplier condition) {
		this.visibility = Objects.requireNonNull(condition);
		return (S) this;
	}

	/** Shorthand for "visible while this boolean setting is on". */
	public final <S extends SettingNode> S dependsOn(BooleanSetting toggle) {
		return visibleWhen(toggle::get);
	}

	/** Marks a persisted value that is edited elsewhere (e.g. HUD position) and never listed in the GUI. */
	@SuppressWarnings("unchecked")
	public final <S extends SettingNode> S internal() {
		this.internal = true;
		return (S) this;
	}

	public final boolean isInternal() {
		return internal;
	}

	public boolean isVisible() {
		return visibility.getAsBoolean() && (parent == null || parent.isVisible());
	}

	void attach(String keyPrefix, SettingGroup parentGroup) {
		this.translationKey = keyPrefix + ".setting." + id;
		this.parent = parentGroup;
	}

	/** Restores the default state of this node (and its children for groups). */
	public abstract void reset();
}
