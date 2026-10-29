package dev.nyxveravisuals.setting;

import java.util.Objects;

/** A button in the settings list. Not persisted. Destructive actions ask the GUI for confirmation first. */
public final class ActionSetting extends SettingNode {
	private final Runnable action;
	private final boolean requiresConfirmation;

	public ActionSetting(String id, Runnable action) {
		this(id, false, action);
	}

	public ActionSetting(String id, boolean requiresConfirmation, Runnable action) {
		super(id);
		this.action = Objects.requireNonNull(action);
		this.requiresConfirmation = requiresConfirmation;
	}

	public boolean requiresConfirmation() {
		return requiresConfirmation;
	}

	public void run() {
		action.run();
	}

	@Override
	public void reset() {
		// Actions carry no state.
	}
}
